# Entre os Andarilhos — Demo técnica R78 no Godot

## Baixar pelo GitHub

Use **Code → Download ZIP** neste repositório e extraia a pasta inteira. Em seguida, importe o `project.godot` conforme os passos abaixo.

## Abrir e jogar

1. Use **Godot 4.4.1 Standard**. A edição .NET não é necessária.
2. Extraia toda a pasta para um caminho curto e gravável, por exemplo `C:/Jogos/Demo_Godot_R78`.
3. No gerenciador de projetos, escolha **Importar** e selecione `project.godot`.
4. Aguarde a importação dos recursos e abra o projeto.
5. Pressione **F5**. A cena inicial já está configurada.

A primeira abertura cria `.godot/` e pode demorar. O pacote usa o renderizador Compatibility. A validação foi feita no Windows; outros sistemas ainda precisam de teste.

## Controles

| Tecla | Ação |
|---|---|
| WASD | Mover |
| Shift | Correr |
| C | Alternar furtividade |
| I | Inventário |
| H | Corpo/saúde |
| E | Interagir com móvel, porta ou janela |
| J | Escolher gaveta do móvel acessado |
| V | Abrir/fechar janela próxima |
| B | Atravessar janela aberta ou cercamento |
| Esc | Cancelar operação/fechar interação |

O personagem começa no hall da H01. Abra as portas para explorar. A mochila e o moletom estão no guarda-roupa, e os outros móveis contêm suprimentos. O inventário usa posicionamento manual. Aguarde a folha terminar de abrir antes de atravessar uma janela. Falta de piso, espaço ocupado ou fôlego insuficiente impedem travessias.

## O que testar

Movimentação e câmera isométrica, furtividade, móveis/gavetas, coleta, equipamento e consumo, portas, quatro mecanismos de janela, travessia compatível na sala e seis cercamentos. Os quatro baixos custam 3 de fôlego; os dois altos custam 12 e têm escalada própria.

Salvar/Carregar estão na barra da demo. O perfil local é `user://demo_h01_inventory_r73.json`. Para reiniciar, feche o jogo, use **Projeto → Abrir pasta de dados do usuário** no editor e remova apenas esse arquivo de perfil. Ele conserva inventário e estados de portas/janelas; posição e mundo completo ainda não têm retomada integral.

## Limites

Demo técnica, sem zumbis ou ciclo completo de sobrevivência. A política de travessia dos zumbis está preparada para futura IA. Meio vão e caminhos bloqueados recusam passagem. Algumas árvores podem prejudicar a visão. Materiais e distribuição ainda são candidatos para avaliação.

Os 36 casos de cercamentos e as regressões de janelas/inventário não substituem testes em outros computadores. Ao relatar um bug, informe Godot, sistema, GPU, passos e os erros/capturas relevantes, evitando dados pessoais.

## Arquivos

Preserve a estrutura de `personagem/`, `player/`, `main/` e `staging/`. Todos os recursos necessários estão nesta pasta. `.import` guarda configurações; `.godot/` é cache e não precisa ser compartilhada. As ferramentas internas de QA escrevem numa pasta `qa/` gravável.

O pacote não altera as licenças dos recursos de origem nem atribui uma licença nova ao projeto.
