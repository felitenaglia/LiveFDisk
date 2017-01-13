[ORG 0x7e00]

; Color: 8 bits bajos -> Color de letra, 8 bits altos -> Color de fondo

%define colorBase	0x0F
%define colorActivo	0xF0
%define colorError	0xC0
%define colorWarning	0x0E

main:
	xor ax, ax
	mov ds, ax		; Inicializamos los registros de segmento
	mov ss, ax
	mov sp, 0xffff

	mov ax, 0xb800
	mov es, ax		; Video mapeado a memoria

	cld
	call dib_GUI		; Dibujamos interfaz

	call nom_discos
	call lee_parts
	call imp_parts

   key_espera:
	mov ah, 0x1
	int 0x16
	jz key_espera

	mov ah, 0h
        int 0x16
	
	cmp al, 0x55
	je key_cambia_unidad	; Si es 'U', cambia unidades
	cmp al, 0x75
	je key_cambia_unidad	; Si es 'u', cambia unidades

	cmp al, 0x45
	je key_elimina_part	; Si es 'E', elimina particion
	cmp al, 0x65
	je key_elimina_part	; Si es 'e', elimina particion

	cmp al, 0x30		; Si es menor o igual a '0', vuelve a esperar tecla
	jle key_espera
	cmp al, 0x35		; Si es mayor o igual al '5' vuelve a esperar tecla
	jge key_espera

	sub al, 0x30		; Restamos '0' para obtener el valor real del numero
	
	mov byte [discoact], al

	call nom_discos
	call lee_parts
	call imp_parts

	jmp key_espera

   key_cambia_unidad:
	not byte [unidades]
	call dib_GUI
	call imp_parts
	jmp key_espera

   key_elimina_part:
	call elim_part
	call lee_parts
	call imp_parts
	jmp key_espera

;-----------------------------------------------------------------------------------------------
; Esta funcion lee, si es posible, el MBR del disco activo (indicado en la variable discoactivo)
; y lo almacena en la direccion 0x00000500. En caso contrario imprime un mensaje de error

lee_parts:			
	mov bx, 0x1f0		; Establecemos el puerto para el primary bus
	mov cx, 0x170
	cmp byte [discoact], 2
	cmovg bx, cx		; Si el disco es mayor que 2 (es decir 3 o 4) es el secondary bus, entonces cambiamos el puerto

	mov dx, bx
	add dx, 0x6         	; Puerto del disco y head
	
	mov al, 0x0a0		; Establecemos que el disco es el master
	cmp byte [discoact], 2
	mov cx, 0x0b0
	cmove ax, cx		; Si el disco es 2 o 4 cambiamos a slave	
	cmp byte [discoact], 4
	cmove ax, cx

	out dx,al

	mov dx, bx
	add dx, 0x2		; Puerto de la cantidad de sectores
	mov al, 1		; Lee un solo sector
	
	out dx, al

	mov dx, bx
	add dx, 0x3		; Puerto del nro de sector
	mov al, 1		; Lee el primer sector
	out dx, al

	mov dx, bx
	add dx, 0x4
	mov al,0
	out dx,al

	mov dx, bx
	add dx, 0x5
	mov al, 0
	out dx, al		; Cilindro 0 del disco

	mov dx, bx
	add dx, 0x7		; Puerto de comandos
	mov al, 20h		; Orden: Leer
	out dx, al

    lp_espera_hdd:
	in al, dx
	test al, al		; si al es cero, entonces hay error o el disp. no existe
	jz lp_error

	test al, 1		; Si hubo error
	jnz lp_error

	test al, 8		; Si esta ocupado
	jz lp_espera_hdd 	; Esperar hasta que este listo

	mov cx, 0x50
	mov es, cx		; Cambiamos el 'es' para indicarle en donde escribir
	mov cx,256		; Vamos a usar rep, le decimos que son 256 iteraciones 
	mov di,0

	mov dx,bx		; Puerto de datos
	rep insw		; Leemos 256 words

	mov ax, 0xb800
	mov es, ax		; Reestablecemos a video mapeado a memoria
	mov ax, 0

	mov byte [oklectura], 1

	mov ecx, 0x6FE
	cmp word [ecx], 0xAA55
	jne lp_no_firmado

	ret

    lp_error:			; Si hay algun error, seteamos en la variable que no se pudo leer
	mov byte [oklectura], 0
	mov ax, 0xb800
	mov es, ax
	ret

    lp_no_firmado:
	mov byte [oklectura], -1
	ret

;-----------------------------------------------------------------------------------------------

dib_GUI:		; Dibuja la interfaz
	mov ah, colorBase
	mov al, 201
	mov di, 164
	stosw

	mov al, 205
	mov cx, 74
	rep stosw

	mov al, 187
	stosw

	mov di, 3684
	mov al, 200
	stosw

	mov al, 205
	mov cx, 74
	rep stosw

	mov al, 188
	stosw	

	mov dx, 21
	mov di, 324
	mov al, 186
    dg_verticales:
	stosw
	add di, 148
	stosw
	add di, 8
	sub dx, 1
	jnz dg_verticales

	mov di, 328 
	mov si, titu
	mov ah, colorBase
	call print_str

	mov di, 488 
	mov si, subt
	mov ah, 0x07
	call print_str

	mov di, 648
	mov si, subt1
	call print_str

	mov di, 436
	mov si, nom
	mov ah, 0x09
	call print_str

	mov di, 1132
	call clr_line

	mov di, 1132
	mov si, cab1
	mov ah, colorBase
	call print_str

	mov di, 1146
	mov si, cab2
	call print_str

	cmp byte [unidades], 0
	jne dg_imp_chs			; Si esta seteada la variable "unidades" salta a CHS
	
	mov di, 1188
	mov si, cab3
	call print_str

	mov di, 1222
	mov si, cab4
	call print_str
	jmp dg_cab_boot    

    dg_imp_chs:
	mov di, 1178
	mov si, cab3a
	call print_str

	mov di, 1220
	mov si, cab4a
	call print_str	
    
    dg_cab_boot:
	mov di, 1252
	mov si, cab5
	call print_str
	ret

;-----------------------------------------------------------------------------------------------

nom_discos:			; Imprime los discos al pie de la pantalla, resaltando el disco activo
	mov dl, [discoact]
	mov dh, colorActivo

	mov ecx, 1
    nd_bucle:
	mov ah, colorBase
	cmp dl, cl
	cmove ax, dx
	mov di, [arr_pos_disk+4*ecx]
	mov si, [arr_nom_disk+4*ecx]
	call print_str
	
	add cl, 1
	cmp cl, 5
	jne nd_bucle

	ret

;-----------------------------------------------------------------------------------------------

print_str:	; Argumentos: ah = Color de letra/fondo, di = Dir. donde escribir, si = Dir. cadena a escribir  
	lodsb
	cmp al, 0
	je ps_fin  
    ps_repet:
	stosw
	lodsb
	cmp al, 0
	jne ps_repet
    ps_fin:
	ret

;-----------------------------------------------------------------------------------------------

print_nro:	; Argumentos: bh = Color de letra/fondo, di = Dir donde escribir (nro menos signif.), eax = Número a imprimir (unsigned)
	push bx	
	std
   pn_division:
	mov edx, 0
	mov ecx, 10
	div ecx		; en edx resto, en eax cociente
	mov ecx, eax
	pop bx
	mov ah, bh
	push bx
	mov al, dl
	add al, 0x30	; le sumamos el valor de '0', para convertirlo a ASCII
	stosw
	mov eax, ecx
	cmp eax, 10
	jge pn_division
	pop bx
	mov ah, bh
	add al, 0x30
	cmp al, 0x30
	je pn_fin
	stosw
    pn_fin:
	cld
	ret

;-----------------------------------------------------------------------------------------------

clr_line:
	mov ecx, 65
	mov ah, 0x0F
	mov al, 32
	rep stosw
	ret

;-----------------------------------------------------------------------------------------------
; Lee lo guardado en 0x500 e imprime en pantalla las particiones, su tipo, si esta marcada como booteo, y el inicio y tamaño, en sectores o
; las ternas: (Cylinder, Head, Sector) de inicio y fin, según corresponda

imp_parts:
	mov edx, 0
    ip_cls:				; Borra de la pantalla las 4 lineas de particiones
	mov di, [arr_pos_part+4*edx]
	call clr_line
	add edx, 1
	cmp edx, 4
	jne ip_cls	

	mov di, 2890
	call clr_line
	mov di, 3050
	call clr_line

	cmp byte [oklectura], 0
	je ip_error_mbr

	cmp byte [oklectura], -1
	je ip_no_firmado

	mov edx, 0
    ip_bucle:
	mov di, [arr_pos_part+4*edx]
	add di, 14
	lea ebx, [4*edx]
	mov ecx, 0x500	
	mov al, byte [ecx+4*ebx+450]
	cmp al, 0x0			; Si es cero no imprime la entrada y salta a la proxima
	je ip_proxima			

	mov si, tip7			; Por default, el tipo es 'Otro'

	mov bx, tip6
	cmp al, 0x5			
	cmove si, bx			; Si es Extendida, copia la direccion de la etiq.

	mov bx, tip5
	cmp al, 0x6
	cmove si, bx			; Si es FAT 16, copia la direccion de la etiq.

	mov bx, tip4	
	cmp al, 0xB
	cmove si, bx			; Si es FAT 32, copia la direccion de la etiq.

	mov bx, tip2
	cmp al, 0x83
	cmove si, bx			; Si es Linux, copia la direccion de la etiq.

	cmp al, 0x82
	mov bx, tip3
	cmove si, bx			; Si es Linux Swap, copia la direccion de la etiq.

	cmp al, 0x7
	mov bx, tip1
	cmove si, bx			; Si es NTFS, copia la direccion de la etiq.	

	mov ah, colorBase
	call print_str

	mov di, [arr_pos_part+4*edx]
	mov si, [arr_nom_part+4*edx]
	mov ah, colorBase
	call print_str			; Imprime el nro de particion

	cmp byte [unidades], 0		; Si esta seteado salta a CHS 
	jne ip_act_chs

	mov di, [arr_pos_part+4*edx]
	add di, 74
	lea ebx, [4*edx]
	mov ecx, 0x500	
	mov eax, [ecx+4*ebx+454]
	mov bh, colorBase

	push edx
	call print_nro			; Imprime el LBA de inicio
	pop edx

	mov di, [arr_pos_part+4*edx]
	add di, 102
	lea ebx, [4*edx]
	mov ecx, 0x500	
	mov eax, [ecx+4*ebx+458]
	mov bh, colorBase

	push edx
	call print_nro			; Imprime la longitud (en sectores)
	pop edx
	jmp ip_booteo

    ip_act_chs:
	mov di, [arr_pos_part+4*edx]
	add di, 42
	mov si, chs_base
	mov ah, colorBase
	call print_str			; Imprime la base para CHS

	lea ebx, [4*edx]
	mov ecx, 0x500
	mov eax, 0
	mov al, [ecx+4*ebx+447]
	mov bh, colorBase
	mov di, [arr_pos_part+4*edx]
	add di, 60
	push edx
	call print_nro			; Imprime "Head"
	pop edx

	lea ebx, [4*edx]
	mov ecx, 0x500
	mov eax, 0
	mov ax, [ecx+4*ebx+448]
	and ax, 0x3F
	mov bh, colorBase
	mov di, [arr_pos_part+4*edx]
	add di, 68
	push edx
	call print_nro			; Imprime "Sector"
	pop edx

	lea ebx, [4*edx]
	mov ecx, 0x500
	mov eax, 0
	mov ax, [ecx+4*ebx+448]
	and ax, 0xC0
	shl eax, 2
	mov al, [ecx+4*ebx+449]
	mov bh, colorBase
	mov di, [arr_pos_part+4*edx]
	add di, 50
	push edx
	call print_nro			; Imprime "Cylinder"
	pop edx

					; Las proximas lineas son análogas a las anteriores, salvo que imprime el fin
	mov di, [arr_pos_part+4*edx]
	add di, 80
	mov si, chs_base
	mov ah, colorBase
	call print_str

	lea ebx, [4*edx]
	mov ecx, 0x500
	mov eax, 0
	mov al, [ecx+4*ebx+451]
	mov bh, colorBase
	mov di, [arr_pos_part+4*edx]
	add di, 98
	push edx
	call print_nro
	pop edx

	lea ebx, [4*edx]
	mov ecx, 0x500
	mov eax, 0
	mov ax, [ecx+4*ebx+452]
	and ax, 0x3F
	mov bh, colorBase
	mov di, [arr_pos_part+4*edx]
	add di, 106
	push edx
	call print_nro
	pop edx

	lea ebx, [4*edx]
	mov ecx, 0x500
	mov eax, 0
	mov ax, [ecx+4*ebx+452]
	and ax, 0xC0
	shl eax, 2
	mov al, [ecx+4*ebx+453]
	mov bh, colorBase
	mov di, [arr_pos_part+4*edx]
	add di, 88
	push edx
	call print_nro
	pop edx

    ip_booteo:
	mov si, boot
	mov di, [arr_pos_part+4*edx]
	add di, 120
	lea ebx, [4*edx]
	mov ecx, 0x500	
	mov al, byte [ecx+4*ebx+446]
	cmp al, 0x80			; Si no es 0x80 no es de booteo
	jne ip_proxima						
	mov ah, colorBase
	call print_str			; Si es de booteo, imprime
	
    ip_proxima:
	add edx, 1
	cmp edx, 4
	jl ip_bucle
        ret

    ip_no_firmado:
        mov si, err_firma
        mov di, 3050
	mov ah, colorError
	call print_str
	ret

    ip_error_mbr:
	mov di, 3050
	mov si, err_lect
	mov ah, colorError
	call print_str
	mov al, [discoact]
	add al, 48
	stosw
	mov al, 32
	stosw
	ret

;-----------------------------------------------------------------------------------------------

elim_part:
	mov di, 2890
	call clr_line
	mov di, 3050
	call clr_line

	cmp byte [oklectura], 0
	je ep_error_mbr
	cmp byte [oklectura], -1
	je ep_no_firmado

	mov ah, colorActivo
	mov di, 2890
	mov si, msg_eliminar_1a
	call print_str
	mov ah, colorActivo
	mov di, 3050
	mov si, msg_eliminar_1b
	call print_str

   ep_key_espera:
	mov ah, 0x1
	int 0x16
	jz ep_key_espera

	mov ah, 0h
        int 0x16

	cmp al, 0x1b		; Si es 'Esc' sale
	je ep_salida
	cmp al, 0x30		; Si es menor o igual a '0', vuelve a esperar tecla
	jle ep_key_espera
	cmp al, 0x35		; Si es mayor o igual al '5' vuelve a esperar tecla
	jge ep_key_espera
	
	sub al, 0x31

	mov edx, 0
	mov dl, al
	lea ebx, [4*edx]
	mov ecx, 0x500	
	mov al, byte [ecx+4*ebx+450]
	cmp al, 0x0		; Si es cero la particion esta vacia
	je ep_part_vacia

	mov di, 2890
	call clr_line
	mov di, 3050
	call clr_line

	mov di, 2890
	mov si, msg_eliminar_3a
	mov ah, colorWarning	
	call print_str
	mov di, 3050
	mov si, msg_eliminar_3b
	mov ah, colorBase
	call print_str
	
    ep_espera_si_no:
	mov ah, 0x1
	int 0x16
	jz ep_espera_si_no	

	mov ah, 0h
        int 0x16
	
	cmp al, 0x4E
	je ep_salida
	cmp al, 0x6E
	je ep_salida

	cmp al, 0x53
	je ep_borra
	cmp al, 0x73
	je ep_borra
	jmp ep_espera_si_no

    ep_borra:
	lea ebx, [4*edx]
	mov ecx, 0x500	
	mov dword [ecx+4*ebx+446], 0x0
	mov dword [ecx+4*ebx+450], 0x0
	mov dword [ecx+4*ebx+454], 0x0
	mov dword [ecx+4*ebx+458], 0x0
	
	mov bx, 0x1f0
	mov cx, 0x170
	cmp byte [discoact], 2
	cmovg bx, cx

	mov dx, bx
	add dx, 6h
	
	mov al,0x0a0
	cmp byte [discoact], 2
	mov cx, 0x0b0
	cmove ax, cx
	cmp byte [discoact], 4
	cmove ax, cx

	out dx,al

	mov dx, bx
	add dx, 0x2
	mov al, 1
	
	out dx, al

	mov dx, bx
	add dx, 0x3
	mov al, 1
	out dx, al

	mov dx, bx
	add dx, 0x4
	mov al,0
	out dx,al

	mov dx, bx
	add dx, 0x5
	mov al, 0
	out dx, al

	mov dx, bx
	add dx, 0x7
	mov al, 30h
	out dx, al

    ep_espera_hdd:
	in al, dx
	test al, al
	jz ep_error_esc

	test al, 1
	jnz ep_error_esc

	test al, 8
	jz ep_espera_hdd

	mov cx,256

	mov si, 0x500
	mov dx,bx
	rep outsw		; Escribimos 256 words

	mov di, 2890
	call clr_line
	mov di, 3050
	call clr_line
	mov di, 3050
	mov ah, colorBase
	mov si, msg_eliminar_4
	call print_str
	jmp ep_espera_escape

    ep_error_esc:
	mov di, 2890
	call clr_line
	mov di, 3050
	call clr_line
	mov di, 3050
	mov ah, colorError
	mov si, msg_eliminar_5
	call print_str
	jmp ep_espera_escape

    ep_part_vacia:
	mov di, 2890
	call clr_line
	mov di, 3050
	call clr_line
	mov di, 3050
	mov si, msg_eliminar_2
	mov ah, colorError	
	call print_str
	jmp ep_espera_escape

    ep_no_firmado:
        mov si, err_firma
        mov di, 3050
	mov ah, colorError
	call print_str
	ret

    ep_error_mbr:
	mov di, 3050
	mov si, err_lect
	mov ah, colorError
	call print_str
	mov al, [discoact]
	add al, 48
	stosw
	mov al, 32
	stosw
	ret

    ep_espera_escape:
	mov ah, 0x1
	int 0x16
	jz ep_espera_escape	
	mov ah, 0h
        int 0x16

	cmp al, 0x1b		; Si es 'Esc' sale
	je ep_salida	
	jmp ep_espera_escape

    ep_salida:
	mov di, 2890
	call clr_line
	mov di, 3050
	call clr_line
	ret
;-----------------------------------------------------------------------------------------------

titu   db "LiveFDisk", 0
subt   db "Proyecto para Arq. del computador (R-222)",0
subt1  db "LCC - 2012",0
nom    db "Felipe A. Tenaglia", 0
cab1   db "Part",0
cab2   db "Tipo",0
cab3   db "Inicio (LBA)", 0
cab3a  db "Inicio (CHS)", 0
cab4a  db "Fin (CHS)", 0
cab4   db "Longitud", 0
cab5   db "Boot", 0

tip1   db "NTFS",0			; 0x7
tip2   db "Linux",0			; 0x83
tip3   db "Linux Swap", 0		; 0x82
tip4   db "FAT 32", 0			; 0xB
tip5   db "FAT 16", 0			; 0x6
tip6   db "Extendida",0			; 0x5
tip7   db "Otro",0			; otro
disk1  db "Disco 1 (PM)",0
disk2  db "Disco 2 (PS)",0
disk3  db "Disco 3 (SM)",0
disk4  db "Disco 4 (SS)",0

chs_base db "(    ,    ,   )",0

part1  db "#1",0
part2  db "#2",0
part3  db "#3",0
part4  db "#4",0
boot   db "**",0

err_lect db " Error al leer el MBR del disco ",0
err_firma db " El MBR le",161,"do no es v",160,"lido (no est",160," firmado) ",0

msg_eliminar_1a db "Ingrese el n", 163 ,"mero de la partici", 162 ,"n que desea eliminar (1-4)",0
msg_eliminar_1b db " o pulse 'Esc' para salir",0
msg_eliminar_2 db " La partici",162,"n ingresada esta vac", 161,"a. Pulse 'Esc' para salir ",0
msg_eliminar_3a db "Advertencia: Se perder", 160, "n TODOS los datos de la partici", 162,"n",0
msg_eliminar_3b db "Pulse 'S' para eliminar, 'N' para cancelar",0
msg_eliminar_4 db "Partici",162,"n eliminada. Pulse 'Esc' para salir",0
msg_eliminar_5 db " Error al eliminar la partici",162,"n. Pulse 'Esc' para salir ",0

discoact db 1		; Disco activo (1=PM, 2=PS, 3=SM, 4=SS)
oklectura db 0		; 1 = Si la ultima operacion de lectura fue satisfactoria, 0 = No fue satisfactoria, -1 = MBR no firmado
unidades db 0		; Unidades 0 = LBA, !0 = CHS


arr_pos_part dd 1454, 1774, 2094, 2414
arr_nom_part dd part1, part2, part3, part4

arr_pos_disk dd 0, 3370, 3402, 3434, 3466
arr_nom_disk dd 0, disk1, disk2, disk3, disk4  ; Los primeros ceros es para que los array's comiencen en el indice 1

times 5120-($-$$) db 0		; Completamos 5k con ceros

