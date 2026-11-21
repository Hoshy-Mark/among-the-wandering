# Roadmap — revisão de interiores, acessos, loot e acabamentos

Atualizado em 21 de novembro de 2026. Plano de trabalho; não significa que as etapas tenham sido implementadas ou aprovadas.

## Base e prioridade

A execução R118 registrou 40 casas, 590 recipientes e sete janelas controladas, restritas à H01. A matriz inicial extraída do cadastro nativo contém **590 recipientes**, agrupados em **548 pares de imóvel/móvel ou superfície**. Recipiente não é sinônimo de armário: gavetas, compartimentos e superfícies contam separadamente. São 412 definições no arquivo de configuração; o cadastro em execução também inclui superfícies levantadas no mapa.

O novo caso prioritário é o **rack da H01**. Existem duas entradas: `H01_FURN_RACK01/storage/drawer_1` e `H01_FURN_RACK01/storage/drawer_2`. O relato de HUD que não abre foi registrado para ambas, com a causa e o compartimento ainda a identificar. Não foram marcadas como testadas ou corrigidas nesta organização.

A matriz completa está em [MATRIZ_RECIPIENTES.json](MATRIZ_RECIPIENTES.json). Todas as revisões completas começam pendentes; os testes pontuais anteriores serão evidências de regressão, não aprovação automática da matriz inteira. Os IDs do mapa devem ser recenseados novamente se a geometria ou o cadastro mudar.

## Ordem das entregas

| Etapa | Entrega | Critério para concluir |
|---|---|---|
| IR-01 | Inventário de acessos e recipientes | Cada porta, janela, móvel e compartimento tem ID, imóvel, alvo, colisão e vínculo com HUD/loot; divergências entre cena e cadastro ficam listadas. |
| IR-02 | H01 funcional completa, começando pelo rack | Todos os móveis e compartimentos da H01 passam nos casos aplicáveis, incluindo as duas gavetas do rack; entrada e saída e os sete acessos de janela recebem regressão. |
| IR-03 | Identidade visual piloto da H01 | Paredes, pisos, batentes, portas e móveis são distinguíveis na câmera de jogo; portas têm atribuição própria de material/textura; comparativo real e medição de custo registrados. |
| IR-04 | Portas, janelas e circulação de todo o mapa | Cada imóvel tem entradas utilizáveis, janelas integradas ao abrir/fechar/atravessar, saídas nos dois sentidos e corredores/colisões verificados; nada é aprovado apenas por estar cadastrado. |
| IR-05 | Revisão integral de móveis, HUD e loot | Todos os recipientes e compartimentos passam na matriz ou têm exceção fundamentada; loot vazio mostra HUD vazio; repetição e salvar/carregar não duplicam ou apagam estoque. |
| IR-06 | Acabamentos visuais em todos os imóveis | Paletas por casa/cômodo e texturas por porta aplicadas; UV, lados internos/externos, folhas móveis, batentes, iluminação e corte de paredes conferidos. |
| IR-07 | Percurso de homologação, persistência e desempenho | Percurso contínuo entre imóveis, teste em processo novo, saves R117/R118, inventário manual, acessos, concentração de zumbis e métricas de FPS/memória aprovados com pendências explícitas. |

A primeira entrega prática é IR-02: H01 funcional completa, começando pelo rack e suas duas gavetas, com diagnóstico do alvo por E/J, abertura física, término do gesto, disponibilidade do HUD e conteúdo real. O levantamento IR-01 acompanha essa entrega. O piloto visual IR-03 vem antes de distribuir materiais pelo mapa inteiro, permitindo conferir a leitura no cenário real.

## Matriz funcional por recipiente

Para cada ID: alcançar pela frente e no pavimento correto; identificar o alvo; abrir e fechar cada parte; lidar com o corpo no arco e obstáculos reais; mostrar o HUD mesmo quando vazio; selecionar o compartimento por E/J; coletar por clique/F; equipar por E quando aplicável; manter o arraste e as células escolhidas; recusar mochila cheia sem perda; cancelar e afastar-se; reabrir sem repor loot; salvar/carregar a quantidade, localização e estado de cada folha; confirmar a retomada em outro processo.

Cada resultado guarda estado, causa de falha e evidência. Casos não aplicáveis precisam de justificativa, como uma superfície sem gaveta. A revisão deve distinguir: falha de seleção, obstrução física, gesto interrompido, HUD oculto, fonte vazia, falha de alocação de loot, item que não cabe na grade e recusa de salvamento. Nenhum item alocado pode desaparecer silenciosamente por falta de espaço. Fontes não interativas precisam ser identificadas visualmente e justificadas no cadastro.

Itens no chão recebem casos próprios: um item, várias pilhas, múltiplas fontes próximas, recolher tudo e reabrir vazio, soltar novamente, mochila cheia, afastamento e salvar/carregar. Não se limita o teste ao chão da H01.

## Direção visual

Manter a geometria poligonal aprovada. A revisão altera acabamentos e leitura espacial.

- **Paredes:** base clara e pouco saturada, com variações por cômodo e casa. Usar diferenças coerentes entre reboco, pintura, azulejo e áreas úmidas.
- **Pisos:** separar das paredes por valor, textura e escala. Madeira, cerâmica e cimento devem ter padrões reconhecíveis na câmera isométrica.
- **Batentes e rodapés:** formar uma borda legível que revele os vãos, sem confundir porta com parede.
- **Portas:** cada instância deve ter atribuição própria de acabamento e textura, incluindo ambas as faces e a folha em movimento. Usar famílias de madeira, pintura e desgaste com variações; não resolver somente tingindo tudo de marrom. Conferir também porta aberta, maçaneta, dobradiça e continuidade com o batente.
- **Móveis:** distinguir a parte móvel da carcaça sem perder a unidade do móvel. Portinhas de armário e gavetas entram na revisão, além das portas de passagem.
- **Janelas e iluminação:** manter vidros/caixilhos legíveis com os cortes de parede e nos dois modos de câmera; conferir espaços sem energia e com a iluminação disponível.

Paleta inicial candidata para o piloto: paredes em off-white quente/cinza suave; piso de madeira castanha ou cerâmica cinza esverdeada; batentes mais escuros; portas em madeira com veio ou pintura gasta. Banheiro/cozinha podem usar cerâmica e pintura mais fria; quartos/sala, tons quentes e variações discretas. Os tons finais serão comparados em capturas reais da H01 antes da expansão.

Cada porta terá sua definição individual no catálogo. Texturas ou atlas e materiais equivalentes podem ser compartilhados; alterar o acabamento de uma porta não deve recolorir outras instâncias por engano. Evitar uma coleção de texturas grandes exclusivas por objeto. Registrar custo de materiais, memória, chamadas de desenho e tempo por quadro em cada lote visual.

## Homologação e preservação

Não basta abrir a porta: o personagem deve entrar e sair, circular pelo cômodo e alcançar o loot. Não basta cadastrar o recipiente: o HUD e os itens devem funcionar pela interação normal. Não basta validar a H01 ou um representante de cada tipo: a matriz completa deve ter resultado por imóvel/compartimento.

Preservar o mapa atualizado, inventário C-05 e organização manual, estoques finitos, saves anteriores, 480 zumbis persistentes, NPCs humanos protegidos e articulação do personagem. Usar perfis de QA isolados. Cada entrega deve conter mudanças, casos que passaram/falharam, capturas reais leves para revisão remota e métricas de desempenho. Falhas bloqueantes ficam explícitas.

O mapa só recebe a condição de explorável após a auditoria de acessos, janelas, circulação, recipientes e persistência. O trabalho visual e as correções funcionais devem passar também pela medição de desempenho; a otimização continua acompanhando a revisão.
