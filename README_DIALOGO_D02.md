# Diálogo D02

Abra este `project.godot` no Godot 4.4.1 e execute `demo_inventory.tscn`. Aproxime-se de Samuel na praça P01 e pressione E.

A conversa usa uma coluna à direita, retrato renderizado do modelo atual, histórico cronológico e respostas na base. Clique ou use números para responder; setas selecionam e Enter confirma. Esc, E ou × solicitam saída, quando permitida. I/H conservam a transição para inventário e corpo. O mundo continua rodando.

As duas respostas atuais e as falas de Samuel permanecem as da R99. As nove opções e o histórico extenso pertencem somente às fixtures de QA. A interface não acrescenta missões, relações ou salvamento paralelo.

O inventário C-05, a HUD de armas R01, o save e o controlador de encontro anteriores foram preservados. Os prompts de teclas consultam o InputMap. Não foi criado F10 ou um modo de teste acessível pelo gameplay normal.

Relatório, capturas, rollback e script para repetir os testes: `docs/dialogo_d02` na raiz do workspace. A D02 integrada aguarda avaliação visual do diretor.
