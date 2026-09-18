# Los Monos Game

Colección de minijuegos sobre las distintas actividades de un turno de trabajo en la empresa **LosMonos**, creada con Godot 4.

## Cómo jugar

- Muévete con las flechas del teclado.
- Usa `Espacio` para recoger grupos de cajas que ya estén en el suelo y para soltarlos.
- Llévalos al puesto azul junto a la estantería y pulsa `Espacio` para organizarlos.
- Al organizar: `←` / `→` eligen la columna, `Q` / `E` giran la pieza y `Espacio` la coloca donde indica la vista previa.
- `Esc` cancela la colocación conservando las cajas; fuera de ese modo vuelve al menú.
- `R` reinicia el nivel. Al terminar también puedes usar `Enter` para repetirlo.

## Actividad 01: orden en altura

Una máquina de poleas recorre un riel en el techo, baja su gancho y deja caer grupos de cuatro cajas. El empleado mono los recoge y organiza en una estantería de 6 columnas y 8 filas con piezas tipo Tetris (I, O, L, J, T, S y Z).

Las piezas se apoyan en el fondo o sobre otras cajas. Las filas completas se despachan y las superiores bajan. El objetivo del primer nivel es completar cuatro filas. Si ninguna posición o giro permite colocar la pieza que llevas, la estantería se considera llena y puedes reintentar.

Recepción admite tres grupos de cajas; al llenarse, la polea espera hasta que recojas alguno. El lote inicial facilita aprender a encajar las piezas; después se usa una bolsa aleatoria de las siete formas. No hay límite de tiempo en este primer nivel.

El título de la portada conserva el azul y tiene un resplandor blanco intermitente detrás de las letras. El efecto usa capas de texto y funciona sin activar bloom.

## Comprobaciones

Con Godot disponible, ejecutar `godot --headless --path . --script res://tests/warehouse_test.gd`. Comprueba giros, límites, apilado, eliminación de filas, caída y recogida, pausa de recepción, partida completa, derrota y animación del neón.

## Tipografías

Pirata One para los títulos y Poppins para el resto de la interfaz. Los archivos se incluyen en `assets/fonts` y el tema global está en `themes/game_theme.tres`.

Ambas fuentes permiten uso comercial bajo la SIL Open Font License 1.1. Consultar [procedencia y condiciones de las fuentes](assets/fonts/README.md); conservar los archivos de licencia al distribuirlas con el juego.
