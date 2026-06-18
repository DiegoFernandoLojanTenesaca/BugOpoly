# Fichas (modelos 3D) — Cute Animated Monsters

Las 21 fichas ya están acá (pack **Quaternius "Cute Animated Monsters"**, CC0).
Cada `<shape>.gltf` se carga solo en el board y el menú, con su animación **Idle**
reproduciéndose y un pedestal del color del jugador.

Fichas: cyclops, ghost, demon, greendemon, cthulhu, yellowdragon, yeti, skull,
bat, bee, crab, alien, alien_tall, mushroom, cactus, tree, panda, pig, deer,
chicken, penguin.

## Escala / orientación
La escala está calibrada por modelo en `PIECE_FIT` (`src/presentation/board_view.gd`),
apuntando a ~1.1 de alto. Si alguno se ve grande/chico/girado al correr, decime
cuál y lo ajusto ahí.

## Cambiar o agregar
Dropeá un `<shape>.gltf` (o `.glb`) con el nombre de la ficha para reemplazarla.
Para una ficha nueva: agregá el modelo acá, una entrada en
`data/bugopoly/piece/pieces.json`, y su escala en `PIECE_FIT`.
