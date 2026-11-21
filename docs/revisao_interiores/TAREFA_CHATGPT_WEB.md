# Trabalho paralelo — auditoria dos interiores e direção visual

## Pedido para colar no outro chat

Você vai trabalhar em paralelo com o Codex local no projeto **Entre os Andarilhos**. Consulte o repositório `Hoshy-Mark/among-the-wandering`, branch `main`, na publicação R118 ou posterior. Informe o commit que conseguiu consultar. Não assuma que conhece conversas anteriores.

Seu escopo é **auditoria estática dos cadastros e especificação visual**. O Codex local fica responsável pelas correções de interação, integração, testes reais no Godot e medições de desempenho. Entregue os resultados nesta conversa ou, se estiver usando Codex web com escrita, somente em arquivos novos dentro de `docs/revisao_interiores/web/`, em branch separada. Não altere scripts, cenas, configurações de loot, materiais existentes nem a matriz de testes compartilhada. Não faça merge automaticamente.

## Leia primeiro

1. `README.md` — estado atual e controles.
2. `docs/r118/REVISAO_R118.md` — correções verificadas e limites.
3. `docs/revisao_interiores/ROADMAP.md` e `ROADMAP.json` — ordem das entregas.
4. `docs/revisao_interiores/MATRIZ_RECIPIENTES.json` — 590 compartimentos e superfícies, todos pendentes de revisão completa.
5. `docs/r117/comparativo_visual.html`, `docs/r118/comparativo_visual.html` e suas imagens — capturas reais disponíveis.

O projeto usa Godot 4.4.1 Standard. A pasta histórica Demo_Godot_R78 não representa a revisão atual. Há 40 casas e 590 recipientes registrados, mas apenas sete janelas integradas ao controlador da demo, todas na H01. O usuário relata falha de HUD no rack da H01; existem duas gavetas, e o compartimento afetado ainda precisa ser reproduzido. Não classifique relatos ou hipóteses como testes aprovados.

## Entrega WEB-01 — auditoria dos dados

Cruze `staging/e06_world/arroio/spatial_loot/config.json`, `layouts.json`, `furniture_moves.json`, `site_clearances.json`, os cadastros de interiores em `staging/e06_world/arroio/data/` e a matriz. Consulte os adaptadores `personagem/map117/world.gd`, `house.gd`, `session.gd` e os mecanismos de `staging/e06_world/arroio/spatial_loot/` para entender como os IDs se conectam.

- Liste IDs duplicados, referências inexistentes, compartimentos sem vínculo, partes móveis ausentes e divergências demonstráveis nos arquivos.
- Separe definições explícitas de superfícies descobertas em execução: 412 definições de configuração não precisam corresponder uma a uma aos 590 registros do runtime.
- Priorize as duas gavetas `H01_FURN_RACK01/storage/drawer_1` e `drawer_2`, sem alterar o código.
- Para cada achado, forneça arquivo, ID, evidência, consequência provável e teste necessário. Se só puder suspeitar, marque como hipótese.
- Não conclua que um objeto não existe no jogo somente porque não foi encontrado em um único JSON; considere glTF e geração dinâmica.

Resultado: `AUDITORIA_CADASTROS.md` e, se útil, `ACHADOS.json`. Prefira tabela curta e acionável. Não transcreva os 590 casos.

## Entrega WEB-02 — piloto visual da H01

O usuário quer distinguir paredes, pisos, portas e vãos na câmera isométrica. Preserve o personagem e a geometria poligonal aprovados. Proponha acabamentos por cômodo, com cores hexadecimais, material, textura, escala e função de contraste. Considere também câmera no ombro, ambientes sem energia e cortes de parede.

- Piso deve se separar visualmente da parede; indique madeira, cerâmica ou cimento com coerência de uso.
- Batentes e rodapés devem revelar os vãos sem depender do texto da interação.
- Cada porta física deve ter atribuição individual de acabamento/textura para as duas faces e folha móvel. Não basta variar a tinta marrom. Identifique as portas reais do cadastro; onde não houver certeza, registre o que precisa ser levantado localmente.
- Inclua portas de armários e gavetas na leitura visual, mantendo unidade com a carcaça.
- Use famílias de texturas/atlas e materiais equivalentes compartilháveis. Definição individual não exige imagem exclusiva grande para cada objeto.
- Consulte `scripts/residential_interiors.gd`, `scripts/z2_finish.gd`, `data/new_model_finishes.json` e `data/civic_finish_review.json` sob `staging/e06_world/arroio/` antes de propor substituições. Observe materiais compartilhados e UV existentes.

Resultado: `PILOTO_VISUAL_H01.md` e `PALETA_H01_PROPOSTA.json`. Se fizer um mockup, identifique-o como proposta; ele não é captura do jogo nem comprova integração.

## Entrega WEB-03 — expansão visual para o mapa

Após especificar o piloto, proponha famílias visuais por tipo de imóvel e uso do cômodo, evitando que todas as casas tenham a mesma tonalidade. Entregue um catálogo de acabamentos de portas, paredes e pisos, com variações econômicas de pintura, madeira, desgaste e azulejo, além de um plano de aplicação por lotes. Inclua orçamento proposto de resolução, reutilização e quantidade de materiais; não apresente estimativas como desempenho medido.

Resultado: `CATALOGO_ACABAMENTOS.md` e `ACABAMENTOS_PROPOSTOS.json`, sempre como especificação para integração local.

## Entrega WEB-04 — roteiro de validação

Revise os critérios da matriz e sugira lacunas de teste: fonte vazia, alvo incorreto, E/J, coleta por clique/F, equipar por E, arraste manual, mochila cheia, cancelamento, reabertura sem reposição e salvar/carregar em processo novo. Inclua itens no chão, acesso aos dois lados das portas e travessias. Os controles do código atual prevalecem; não crie novos atalhos.

Resultado: `LACUNAS_DE_TESTE.md`, com passos reproduzíveis e resultado esperado. Deixe os resultados reais como não executados.

## Preservar e devolver

Preserve inventário C-05 e organização manual, loot finito, saves anteriores, 480 zumbis persistentes, humanos protegidos e o rig aprovado. Não invente itens, estoque ou evidências de gameplay. O Codex local começa pelo rack e revisão funcional da H01, depois acessos/janelas e testes de todos os recipientes. A aplicação do piloto visual depende de sua especificação e de validação local.

Devolva, por etapa, arquivos produzidos, achados confirmados, hipóteses e perguntas que realmente dependam do jogo. Termine com um resumo curto que possa ser trazido ao chat local. Não é necessário repetir toda a história do projeto.
