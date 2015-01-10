; B1 font file
; 8x8 pixels VGA CP437 raster font

	.segment "FONT"
	.org $F400
	.incbin "font.dat"
