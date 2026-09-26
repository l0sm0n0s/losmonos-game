# Los Monos Game

Colección de minijuegos sobre las actividades de un turno de trabajo en **Almacén Los Monos**, creada con Godot 4. El primer nivel combina plataformas y acomodo de paquetes tipo Tetris en una bodega de vista lateral.

## Cómo jugar

- Camina con `←` / `→` o `A` / `D`.
- Salta con `Espacio` (también `↑`). Mantén Espacio para un salto alto; suéltalo antes para uno corto.
- Pulsa `F` junto a un paquete para recogerlo. El contorno claro indica cuál estás seleccionando.
- Mientras lo llevas, `Q` / `E` giran el grupo de cajas en ambos sentidos.
- Acércate al lugar de acomodo y mira hacia él. La silueta azul indica una posición válida; la roja indica que no cabe, no tiene apoyo o está fuera de alcance.
- Pulsa `F` para colocarlo directamente en esa posición. Puedes seguir caminando y saltando con el paquete: no hay un modo de tablero separado.
- Puedes recoger nuevamente las piezas colocadas, siempre que las restantes conserven una cadena de apoyo hasta el suelo. Si una caja sostiene otras, retira primero las de arriba.
- Para dejar un paquete a un lado, apunta hacia un espacio libre de recepción y pulsa `F`. Allí vuelve a caer con gravedad.
- `R` reinicia el nivel; `Esc` regresa al menú. Al completar el nivel, `Enter` o `Espacio` también permiten repetirlo.

## Actividad 01: orden en altura

Una máquina de poleas se desplaza por el techo y suelta grupos de cuatro cajas en recepción. Los paquetes caen con gravedad y tienen una colisión por cada caja. El mono tiene aceleración, gravedad y salto propios, y puede caminar sobre las pilas, saltarlas y transportar paquetes mientras se mueve.

La zona de acomodo ocupa 20 columnas de la bodega y admite hasta 6 filas de altura. El objetivo es completar **4 filas sin ningún hueco**, de una marca azul del suelo a la otra. Las filas terminadas **no desaparecen**: siguen siendo plataformas para alcanzar el siguiente nivel. Al retirar un paquete se recalculan las filas completas.

El acomodo se ajusta a celdas de 32 píxeles junto al personaje. Las piezas necesitan suelo u otra caja como apoyo, no pueden solaparse con el mono ni con otros paquetes y solo se colocan a una altura alcanzable. Es posible rellenar huecos laterales que admitan la forma.

La polea espera si la zona de descarga está ocupada, incluso por el personaje, y limita a dos los paquetes pendientes (incluido el que llevas). Vuelve a entregar cuando despejas recepción. El lote inicial de cuadrados y parejas L/J tiene solución en cuatro filas; después se usa una bolsa aleatoria de las siete formas I, O, L, J, T, S y Z.

Este primer nivel no tiene límite de tiempo ni derrota automática por falta de espacio: puedes reorganizar, dejar piezas en recepción o reiniciar. El menú conserva sus acentos azules y el resplandor blanco intermitente detrás del título.

## Comprobaciones

Con Godot disponible, ejecutar:

```text
godot --headless --path . --script res://tests/warehouse_test.gd
```

La prueba comprueba los giros, límites, apoyos, conservación de filas, caída física de paquetes, recogida, bloqueo y reanudación de la polea, colisiones del personaje, salto sobre cajas, aterrizaje encima de ellas, transporte durante el salto, reorganización, partida completa, reinicio, navegación y neón del menú.

## Tipografías

Pirata One para los títulos y Poppins para el resto de la interfaz. Los archivos se incluyen en `assets/fonts` y el tema global está en `themes/game_theme.tres`.

Ambas fuentes permiten uso comercial bajo la SIL Open Font License 1.1. Consultar [procedencia y condiciones de las fuentes](assets/fonts/README.md); conservar los archivos de licencia al distribuirlas con el juego.
