# Los Monos Game

Colección de minijuegos sobre las actividades de un turno de trabajo en **Almacén Los Monos**, creada con Godot 4. El primer nivel combina plataformas y supervivencia ante un brazo robótico que descarga piezas tipo Tetris en una bodega de vista lateral.

## Cómo jugar

- Camina con `←` / `→` o `A` / `D`.
- Salta con `Espacio` (también `↑`). Mantén Espacio para un salto alto; suéltalo antes para uno corto.
- Pulsa `F` junto a una pieza que haya aterrizado para recogerla. El contorno claro indica cuál estás seleccionando.
- Mientras la llevas, `Q` / `E` giran el grupo de cajas.
- Pulsa `F` para soltarla junto al personaje. La silueta azul indica un espacio libre; la roja indica que no cabe. Puedes hacerlo por toda la bodega, incluso mientras saltas; las piezas caen con gravedad.
- Mueve las piezas y mantén las pilas bajas para despejar el recorrido del brazo. Puedes caminar y saltar sobre las cajas.
- `R` reinicia; `Esc` regresa al menú. Tras perder, `Enter` o `Espacio` también permiten repetir.

## Actividad 01: sobrevive al turno

El brazo robótico inicia una entrega al comenzar y repite el ciclo cada **5 segundos**. Elige un punto aleatorio a lo ancho de toda la bodega, se desplaza, baja la carga, la suelta y se recoge. Los destinos respetan el ancho de cada pieza y las paredes, pero no evitan las pilas existentes. El intervalo se puede ajustar con `delivery_interval` en el nodo principal (de 3 a 30 segundos).

Las entregas usan una bolsa aleatoria de las siete formas I, O, L, J, T, S y Z. No hay un límite de piezas pendientes ni pausas por recepción ocupada. Las piezas descargadas se acumulan y siguen sometidas a gravedad; al quitar una base, las piezas superiores caen.

**Pierdes cuando el brazo o su carga suspendida chocan con una pieza entregada anteriormente**, tanto durante el traslado como durante la bajada, la retirada o la espera. También cuentan las piezas que estás transportando. El personaje no activa esta derrota. Las colisiones se comprueban por caja y a lo largo del movimiento del brazo para evitar que atraviese obstáculos entre fotogramas.

El objetivo es resistir el mayor tiempo posible. El marcador muestra segundos y piezas recibidas; ya no hay victoria por completar filas. Al chocar, se detienen el brazo, las entregas, el personaje y las piezas, y aparece el resultado con la opción de reiniciar.

## Adaptación al monitor

Al iniciar, el juego detecta el área disponible del monitor y abre una ventana centrada que ocupa hasta el 90 % de ese espacio, respetando la barra de tareas. Si mueves la ventana a otro monitor o cambias la resolución, vuelve a ajustarse automáticamente. Puedes redimensionarla manualmente: conserva ese tamaño mientras no cambie el monitor ni su área disponible.

`F11` alterna entre ventana y pantalla completa. El mapa, el menú y los controles escalan juntos conservando la proporción 16:9. En otras proporciones aparecen franjas para mantener todo visible. Las coordenadas del juego siguen siendo 960 × 540, así que la resolución no cambia las físicas ni la dificultad.

### F11 al probar desde el editor

Godot no permite cambiar a pantalla completa cuando el juego está integrado en el editor, incluida la ventana flotante con la barra de herramientas de Game. Para probar F11, detén la partida, abre la pestaña **Game/Juego**, abre el menú de la esquina superior derecha y desactiva **Embed Game on Next Play**. Vuelve a ejecutar y haz clic dentro del juego antes de pulsar F11. En teclados que reservan las teclas de función para controles multimedia puede hacer falta `Fn + F11`.

Esta limitación del editor está documentada en [Game embedding](https://docs.godotengine.org/en/4.7/tutorials/editor/game_embedding.html). El juego ejecutado en una ventana independiente admite F11 tanto en el menú como durante la partida.

## Comprobaciones

Con Godot disponible, ejecutar:

```text
godot --headless --path . --script res://tests/warehouse_test.gd
godot --headless --path . --script res://tests/display_test.gd
```

La prueba comprueba destinos en todo el mapa, límites de las piezas, entregas periódicas sin el límite anterior, caída física, choques del brazo en sus distintas fases, ausencia de entregas tras perder, transporte, giros, colocación, salto sobre cajas, eliminación de la victoria por filas, reinicio, navegación y neón del menú.
La prueba de pantalla verifica resoluciones pequeñas, Full HD, QHD, 4K, ultrapanorámicas y verticales. Ejecutada sin `--headless`, también comprueba el monitor real, el redimensionamiento manual y la entrada y salida de pantalla completa mediante eventos de F11 en el menú y durante la partida.

## Tipografías

Pirata One para los títulos y Poppins para el resto de la interfaz. Los archivos se incluyen en `assets/fonts` y el tema global está en `themes/game_theme.tres`.

Ambas fuentes permiten uso comercial bajo la SIL Open Font License 1.1. Consultar [procedencia y condiciones de las fuentes](assets/fonts/README.md); conservar los archivos de licencia al distribuirlas con el juego.
