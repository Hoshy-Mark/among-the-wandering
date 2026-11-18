# Personagem R53

O personagem usa um esqueleto com 58 ossos. Os 52 nomes e matrizes de repouso anteriores são acompanhados por ElbowSupport, ForearmTwist e WristSupport em cada braço. As mãos articuladas usam suas poses e nomes anteriores.

## Articulação

`articulacao_bracos.gd` calcula os suportes a partir das poses correntes dos braços. O componente visual chama essa atualização em `advance(delta)`. O suporte do cotovelo interpola as rotações dos segmentos e sustenta a seção da dobra. ForearmTwist distribui parte da torção da mão pelo antebraço. WristSupport faz a passagem para a mão.

Os arquivos de corpo, corpo segmentado, máscaras e as bases de camiseta, camisa, moletom e paletó pertencem à R53. Use o conjunto exportado para manter os índices de skin e os ossos de suporte coerentes. As máscaras pré-calculadas são geradas com renderização gráfica do Godot.

## Ações

Os clipes eat, drink, medicine e bandage retomam as ações completas, com duração de 3,2 s, 3,5 s, 3 s e 4 s. As trajetórias usam os centros articulares medidos na malha. O controlador `consumo_cuidados.gd` recebe `setup(actor)` uma vez e assume a atualização manual do personagem.

`begin(effect, kind)` inicia a ação com um callback que retorna bool. O integrador confere o item e aplica o consumo ou cuidado nesse callback. `advance(delta)` atualiza o personagem e a ação. `cancel("walk")` interrompe e retorna à caminhada. A pausa usa `actor.motion_paused`.

O estoque e os contadores de efeito da bancada ficam em `suprimentos_teste.gd`. O curativo visual confirmado aparece no antebraço esquerdo. `clear_dressing()` remove essa representação. Os estados persistentes de fome, sede e saúde são fornecidos pelo jogo.

## Testar

No projeto de Arroio, os atalhos 1, 2, 3 e 4 acionam as ações. Esc cancela. A bancada aproximada oferece os mesmos comandos e vistas adicionais. A galeria da R53 inclui imagens de comparação das malhas na mesma pose e as capturas no cenário isométrico.
