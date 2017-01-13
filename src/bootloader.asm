[ORG 0x7c00]
main:
	xor ax, ax
	mov ds, ax	; Inicializamos los registros de segmento
	mov ss, ax
	mov sp, 0x7bff

	mov ah, 02h
	mov al, 10	; Carga 5K (10 sectores)
	mov dh, 0	; en dl ya nos deja el id del drive cargado
	mov ch, 0
	mov cl, 2
	mov bx, 0x0
	mov es, bx
	mov bx, 0x7e00
	int 13h
	mov ah, 01h
	mov cx, 2607h
	int 10h		; Esta interrupcion oculta el cursor
	mov ax, 0xb800
	mov es, ax	; Video mapeado a memoria
	jc error_load
	call clear_scr
	jmp 0x00007e00	

error_load:
	call clear_scr
	mov si, error
	mov di, 0
    esc_e:
	lodsb
	mov ah, 0x0F
	stosw
	cmp al, 0
	jne esc_e
hang:
	jmp hang

clear_scr:
	mov cx, 2000 	; 80 columnas x 25 filas
	mov ah, 0x0F
	mov al, 32
	rep stosw
	ret


error   db "Error al cargar LiveFDisk",0

	times 510-($-$$) db 0
	dw 0xAA55
