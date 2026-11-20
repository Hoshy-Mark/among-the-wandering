# R112 — abastecimento físico e persistência no mapa dos nove personagens

## Entrega

Primeiro lote técnico da etapa de exploração/sobrevivência, mantendo a demo final com os 21 personagens. Os nove já integrados permanecem como base de testes; os doze restantes aguardam autoria. Esta revisão não modifica seus diálogos, relações, habilidades ou posições.

A partida nova passa a usar estoques físicos nos móveis existentes da H01. As três fontes de armas de laboratório no chão deixam de ser criadas no fluxo atual. As mesmas quantidades de armas, munição e suprimentos são distribuídas explicitamente em células válidas de dez compartimentos, pertencentes a oito móveis. Fontes e quantidades continuam candidatas de balanceamento, sem atribuir propriedade narrativa da H01 a algum personagem.

## Distribuição inicial

| Fonte | Conteúdo |
|---|---|
| Guarda-roupa principal | Mochila escolar, moletom e carabina girada manualmente na linha inferior |
| Geladeira | Uma água e duas unidades de comida |
| Despensa | Duas unidades de comida |
| Armário da pia | Duas bandagens |
| Cômoda, gaveta 1 | Dois medicamentos |
| Rouparia, gaveta 1 | Botas sobressalentes |
| Balcão, gaveta 1 | Bastão e barra de metal em posições explícitas |
| Rack, gaveta 1 | Pistola e 18 cartuchos compatíveis |
| Cômoda, gaveta 2 | Revólver |
| Rack, gaveta 2 | 16 cartuchos de carabina |

O protagonista mantém a roupa inicial e uma bandagem no bolso. A montagem completa possui 20 instâncias de item, incluindo roupas equipadas. Nenhuma arma é equipada automaticamente. Quantidades são as mesmas do lote anterior; mudou a origem física dos equipamentos, sem aumentar o arsenal.

## Correção de atomicidade

O código anterior de `_new_inventory()` apagava itens da instância viva e os adicionava em sequência. Uma fonte ausente, item inválido ou encaixe incorreto poderia abortar a montagem após alterar parcialmente a partida.

`abastecimento112.gd` monta tudo numa instância isolada do mesmo inventário real, copiando catálogo e âncoras. Só as quatro peças de vestuário equipadas são mantidas para a nova partida. Os IDs, contagens, coordenadas, rotação, fontes e encaixes são validados antes de publicar o snapshot completo. Falha tardia não apaga itens, não emite sinais intermediários e não muda a organização existente. A publicação termina com a atualização normal de C05.

O serviço não procura espaços livres, não reempilha e não organiza a mochila do jogador. Os encaixes de autoria são explícitos no JSON. Itens com contagem fracionada, fontes duplicadas e sobreposições são recusados.

## Preservação de saves

O abastecimento é usado ao criar a partida. Abrir um móvel ou carregar um save não executa a receita novamente. Recursos consumidos permanecem consumidos; recipientes vazios continuam vazios.

Campanhas R109 preservam todos os seus itens, posições de grid, UIDs, munição e fontes de chão anteriores. Carregar não converte ou redistribui o inventário antigo. Assim, a nova distribuição será vista numa partida nova; ela não é uma migração destrutiva das fontes de quem já jogou.

A autoridade de salvamento continua em `partida107.gd` e a estrutura dos campos não foi alterada. Os testes usam arquivos em `qa/supplies112/`, preservando o perfil pessoal. O carregamento do checkpoint anterior é conferido sem regravá-lo.

## Arquivos

- `demo_inventory.gd`: escolhe a receita física na cena atual e prepara/publica o inventário de forma atômica. As bancadas históricas continuam lendo a receita original.
- `demo_supplies112.json`: receita de autoria das fontes físicas.
- `abastecimento112.gd`: preparação isolada e publicação validada.
- `qa_supplies_model112.gd`: testes de integridade, falhas e conservação dos estoques.
- `qa_supplies112.gd`: testes com personagem, fontes, ações, UI e salvamento reais.

O mecanismo existente de armas encontra os itens que já foram criados e não abre fontes de laboratório adicionais. As classes de combate, arma, inventário, roupa e UI permanecem iguais.

## Como avaliar

Na publicação GitHub, siga o README da raiz: importe `project.godot` no Godot 4.4.1 e pressione F5. O diretório de dados público da R78 foi mantido para compatibilidade, e a campanha atual usa `user://demo_population_r98.json`. O launcher de autoria citado na entrega local não faz parte desta cópia pública.

## Verificação

A validação no mapa abre os móveis, equipa uma mochila, transfere água/comida para células escolhidas, cancela uma ação antes do efeito, consome recursos, equipa pistola, recarrega com munição finita e confere ausência de duplicação. Também testa falha tardia da montagem com o inventário vivo e alternância entre checkpoint novo e R109. A retomada em outro processo confere estoques vazios, posição manual dos itens, munição carregada, nove atores e 480 zumbis.

As contagens finais estão em `QA_RESULTADOS.json`. As seis suítes sociais anteriores foram repetidas: 432 verificações passaram (191 R101–R105 e 241 R109). O teste do abastecimento passou em 32 verificações de dados. As capturas são do renderer real; os JPEGs da galeria são leves para acesso remoto.

## Pendências do bloco de exploração

A H01 ainda usa o adaptador de compatibilidade para seus móveis, portas e saves C05. Esta entrega não promove uma migração integral da geometria/interior para o controlador do outro chat. Também não fixa um novo spawn exterior, não povoa todas as casas com loot e não encerra a etapa 2 inteira. Esses pontos continuam como próximos lotes, com teste de percurso, acesso e compatibilidade. O mapa, as malhas e os 480 indivíduos não foram redesenhados.

O aviso preexistente sobre a textura de profundidade do lago continua fora do escopo. A publicação disponibiliza o projeto Godot; a exportação de executável continua pendente. A verificação específica desta cópia está em `PUBLICACAO.md`.
