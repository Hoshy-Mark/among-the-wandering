# R113 — porta e janela da H01

## Comportamento corrigido

Ao abrir ou fechar uma porta, se somente o jogador ocupar o arco da folha, o personagem dá um passo curto para uma posição livre. A porta começa a mover assim que o arco fica seguro, sobrepondo o fim do recuo. O percurso usa movimento com colisão e piso validado; não teleporta, não remove colisões e não força a passagem por móveis ou outros atores. Se não houver espaço seguro, a operação continua sendo recusada. Pausa e Escape são respeitados, os controles são devolvidos ao terminar e salvar durante a operação é recusado.

A janela da imagem corresponde à H01/window/04. A cama de solteiro interceptava a entrada e a chegada da trajetória central. A nova seleção procura uma faixa lateral livre dentro do vão e valida toda a trajetória, incluindo pés e alinhamento. Nesta janela, a faixa fica 30 cm ao lado da linha anterior. A entrada usa uma versão espelhada do clipe já aprovado, preservando a animação completa das pernas e os apoios. A biblioteca foi gerada antes da execução e tem cerca de 224 KiB; o espelhamento não é calculado por quadro.

Também foi corrigido o alinhamento quando o jogador está muito próximo do caixilho: uma pequena recuperação física ao sair do contato não cancela automaticamente a ação nem puxa o personagem de volta contra a peça. Colisões que bloqueiam o caminho continuam interrompendo a aproximação.

## Verificação no Godot

100 verificações principais e 6 de proteção/regressão passaram no renderer Compatibility. Foram exercitadas abertura e fechamento das três portas interiores com recuo, pausa, cancelamento, obstáculo físico, janela original 01 e janela 04 nos dois sentidos a 30/60/120 FPS, execução única do efeito, devolução do controle e restauração da reserva. Cercas baixas e altas continuam com seus movimentos e custos existentes. A campanha de avaliação usa somente `qa/interactions113/`.

Desvio máximo medido nos pés animados frente às amostras físicas: 6.00 mm. A continuidade das articulações ficou dentro dos limites existentes: cotovelo 22.10 mm; punho 3.79 mm. Malhas, esqueleto, inventário manual, munição, nove personagens e 480 identidades de zumbis foram preservados.

Para repetir, abra o projeto no Godot 4.4.1 ou execute:

```text
godot --path . --script res://tests/interactions113_boot.gd -- --interaction113-test
```

## Limites e próxima frente

Esta correção libera a janela mostrada, sem tornar qualquer abertura atravessável por força. Vãos estreitos e chegadas realmente bloqueadas continuam recusados. A janela 05, por exemplo, ainda tem a cama de casal ocupando sua trajetória segura; não foi removida a colisão dessa cama. O adaptador H01 e o aviso da textura do lago permanecem.

A direção do usuário após esta entrega é foco exclusivo em otimização: medir carregamento, tempo por quadro, renderização, física, simulação e memória antes de cada mudança. Expansões de conteúdo e novas animações ficam em espera; a demo final continua com 21 personagens, dos quais nove estão integrados.
