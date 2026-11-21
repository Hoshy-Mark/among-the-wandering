# R115 — FPS e atualização visual por distância

## Resultado local

| Trecho | FPS R114 | FPS R115 | Quadro médio (ms) | P95 (ms) | Zumbis com modelo ativo |
|---|---:|---:|---:|---:|---:|
| Início H01 | 11.9 | 106.8 | 83.85 → 9.37 | 98.27 → 14.72 | 0 |
| Perto de Renata e Ricardo | 9.7 | 85.4 | 102.78 → 11.72 | 136.75 → 30.91 | 1 |
| Mata: seis zumbis ativos | 6.9 | 74.7 | 145.91 → 13.39 | 161.27 → 28.30 | 6 |

Medição no Godot 4.4.1 Standard, Compatibility, Windows, Ryzen 5 8600G / Radeon 760M, 1280×720. VSync e limitador foram desligados apenas nos processos de avaliação. O FPS da tabela é 1000 dividido pelo tempo médio entre quadros. Estes são testes locais curtos; não representam um mínimo garantido para todo o mapa ou outros computadores.

H01 e NPCs tiveram as mesmas chamadas de desenho e primitivas nas duas versões: respectivamente 1.098 / 1.919.735 e 675 / 1.599.882. O ganho principal veio de retirar cálculos repetidos da CPU. A população permaneceu em 480 registros, com nove humanos.

## Implementação

- `visual_budget115.gd` agenda apenas a apresentação dos humanos estacionários. A até 35 m do jogador, dentro do campo da câmera com margem de 2 m, ou em diálogo, a atualização permanece em cada tick. Fora dessas condições, a pose é avaliada aproximadamente cinco vezes por segundo. O tempo é acumulado e aplicado no próximo avanço; a aproximação ou entrada na câmera libera a atualização imediatamente. As fases iniciais são distribuídas para evitar que todos atualizem juntos. Pausar não acumula tempo.
- `humano99.gd` usa esse agendamento sem desativar corpos físicos, identidade, diálogo ou dados sociais. A malha, as roupas, as mãos e os cálculos das articulações continuam os aprovados.
- `residential_interiors.gd` restaura paredes/telhados ao sair e deixa de repetir seus ajustes em casas que continuam externas. Entrar, sair e os comandos de revisão preservam a atualização. A chamada explícita com delta zero continua forçando a restauração usada pelos interiores cívicos.
- `motor_populacao98.gd` e `zumbis98.gd` atualizam as células de separação quando um ator muda de célula ou de estado vivo/morto. A revisão completa já existente na simulação afastada continua em 5 Hz, na configuração atual. Foi removida a reconstrução adicional a cada tick e a atualização duplicada no passeio dos atores ativos.

A apresentação física dos zumbis já seguia uma faixa de proximidade de 36 m para ativar e 54 m para retirar o modelo quando permitido pelo estado. Isso continua igual: seus dados sobrevivem à retirada do modelo. Perseguições, ataques, reações, travessias e os movimentos dos zumbis próximos mantêm as regras e a frequência anteriores. Este lote não acrescenta geração de zumbis.

## Testes e integridade

- 2751 verificações unitárias no modo headless, incluindo conservação do tempo, retorno ao ritmo completo, câmera ortográfica/perspectiva e 600 comparações do índice incremental com uma reconstrução independente.
- 2769 verificações unitárias na janela nativa; a quantidade de amostras do campo da câmera varia com a proporção do viewport.
- 229 verificações de integração R115: equivalência dos cortes de interiores residenciais/cívicos, entrada/saída, unidades, revisão forçada, sincronização espacial de atores, morte/restauração, pausa e diálogo.
- Mais 100 verificações de portas/janelas, seis de cancelamento, obstruções e cercas, e cinco de salvar/carregar. Campanha R112 continua carregando; inventário C-05 manual e dados sociais preservados.
- As regressões de braços e apoios dos pés continuam aprovadas. Nenhuma mudança de malha ou de coreografia foi necessária.

Os arquivos de teste usam perfis próprios sob `qa/`, ignorados pelo Git. A imunidade ao dano existe somente no cenário de medição para que a partida não termine durante a amostra. O jogo normal permanece com seu dano e seus limites anteriores.

## Método e comparação da mata

O teste de exploração usa 240 quadros no início e 180 perto dos NPCs, após aquecimento, com IA e física ativas. As versões R114 dos quatro scripts alterados são injetadas apenas na memória do processo baseline, a partir de `tests/fixtures115/`; os arquivos do jogo não são reescritos. A referência vem do commit `f352d164c6a7719f32bd5318209c30d97a20c1cd`.

A primeira exploração da mata terminou com seis zumbis no baseline e dois na versão otimizada, em locais diferentes. Esse par foi descartado como comparação de FPS; os dados brutos continuam nos arquivos de exploração para transparência.

A medição válida da mata usa `woodland115.gd`: mesmo ponto inicial e mesmas seis identidades/posições verificadas nas duas execuções, três segundos de aquecimento e oito segundos de amostragem. Os seis permaneceram ativos durante toda a coleta, com IA, ataques, colisões e animações funcionando. As outras 474 identidades continuam nos dados e na simulação normal. As capturas mostram momentos diferentes do combate, por isso os contadores de desenho oscilam com a movimentação e as copas. Não houve redução de frequência dos zumbis para medir o ganho.

## Repetir

Importe primeiro o projeto no Godot 4.4.1 Standard e execute os comandos separadamente:

```text
godot --headless --path . --script res://tests/unit115.gd
godot --path . --script res://tests/performance115.gd -- --baseline115
godot --path . --script res://tests/performance115.gd -- --verify115
godot --path . --script res://tests/woodland115.gd -- --baseline115
godot --path . --script res://tests/woodland115.gd
```

`tests/fps115.gd` é o diagnóstico de isolamento: ele congela temporariamente subsistemas para localizar o custo e os restaura. Esse congelamento não faz parte do runtime entregue.

## Próxima frente de otimização

A memória do mapa ainda é carregada de forma semelhante à R114; este lote não implementa streaming de texturas ou descarregamento de bairros. Os próximos alvos são agrupamento espacial e visibilidade dos cenários, vegetação/sombras, rotas mais longas com maior concentração de zumbis e orçamento de memória por região. O foco de desenvolvimento continua exclusivamente em otimização.
