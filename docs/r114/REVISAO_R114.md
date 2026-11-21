# R114 — primeira otimização de carregamento e cálculo das mãos

## Resultado medido

| Medida | R113 | R114 |
|---|---:|---:|
| Montagem até o jogo estar pronto | 140.39 s | 37.04 s |
| Memória estática reportada pelo Godot | 1509.06 MiB | 1509.12 MiB |
| Tempo médio por quadro | 93.51 ms | 92.75 ms |
| Chamadas de desenho por quadro | 1098 | 1098 |
| Primitivas renderizadas por quadro | 1919735 | 1919735 |
| Nós | 80606 | 80606 |

O carregamento ficou 73.6% menor nesta medição. O FPS permaneceu praticamente igual; esta entrega ainda não resolve o custo por quadro. Uma execução exploratória anterior variou no FPS, por isso o resultado final acima é o que sustenta a conclusão.

## Alterações

`catalog_cache114.gd` mantém snapshots privados dos catálogos ajustados durante a montagem. A cidade consultava `landscape` 429 vezes e `urban_dressing` 719 vezes, repetindo leitura, parse e todas as camadas de correção. Cada consumidor continua recebendo uma cópia independente. Trocas de variante H02 e dos sinalizadores da cidade invalidam os snapshots; existe também invalidação explícita. O bootstrap libera esses snapshots depois de preparar o personagem, menu e mundo, evitando reter a memória de montagem durante a partida.

`maos.gd` reutiliza a conversão das poses JSON em transformações. Cada atualização recebe uma cópia de trabalho para preservar os clipes, as misturas e alterações feitas por outros serviços. Selecionar uma pose invalida seu template. Os microtestes registraram cerca de 45% menos tempo nessa operação nas duas bases. A frequência de animação não foi reduzida. Malhas e cálculos dos apoios dos braços permanecem os anteriores.

## Verificação

- 18428 verificações de catálogos, isolamento das cópias, invalidação, poses e clipes de dedos.
- 1044 poses de corpo nas bases masculina e feminina; erro máximo observado nas transformações: 0.000000600.
- 100 verificações de portas/janelas, seis de proteção e cercas e cinco de salvar/carregar, incluindo campanha R112.
- Mesmos 180 modelos agrupados, 1.001.104 triângulos na contagem do agrupador, nove humanos e 480 identidades de zumbis.
- Geometria, chamadas de desenho, primitivos e número de nós iguais nas duas medições.

Os testes usam perfis em `qa/performance114/`. `publication_r112.json` é uma campanha autoral de teste; nenhum perfil pessoal foi incluído.

## Como repetir

Depois de importar no Godot 4.4.1 Standard, execute com o renderer Compatibility:

```text
godot --path . --script res://tests/equivalence114.gd --headless
godot --path . --script res://tests/performance114.gd -- --perf114-baseline
godot --path . --script res://tests/performance114.gd -- --perf114-optimized --perf114-verify
```

O baseline injeta em memória as versões anteriores de `city.gd` e `maos.gd`; os arquivos do jogo não são reescritos. A instrumentação mede etapas inclusivas, portanto não se deve somar etapas-pai e etapas-filhas. O cenário medido é o início H01, 1280×720, com importação já aquecida, VSync e limitador de FPS desativados somente no processo de avaliação. Há zero zumbis com apresentação física nessa área inicial; as 480 identidades e a simulação afastada continuam presentes. O teste não representa combate, todos os lugares do mapa nem importação fria. A captura e os dados completos ficam nesta pasta.

## Próximos gargalos

O perfil aponta custo elevado na atualização das poses dos nove NPCs, na física/simulação e nas rotinas de corte dos interiores. O renderer mantém 1.098 chamadas e aproximadamente 1,92 milhão de primitivas nesta vista. O próximo lote continua exclusivamente em otimização, com medições separadas de animação, física e renderização antes de alterar cada sistema.
