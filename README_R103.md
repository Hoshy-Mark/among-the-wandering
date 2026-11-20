# R103 — Gabriel e Josué

Execute a cena padrão do projeto na Godot 4.4.1. Agora há três encontros conversáveis: Samuel na P01; Gabriel e Josué em pontos públicos provisórios na fachada da igreja EST01, setor S05, junto à V01. Não são residências ou rotinas definitivas.

E inicia a conversa; clique ou números/Enter escolhem respostas; Esc sai. P abre habilidades fora da conversa. I/H mantêm inventário/corpo. Armas continuam nas setas e 1–4 fora das interfaces.

Ouvir de Gabriel que ajuda na igreja abre um assunto correspondente com Josué. Respeito, confiança e testes pertencem ao NPC envolvido. Conhecimento e aprendizado do jogador persistem entre conversas. A confirmação do mesmo fato não duplica experiência. As falas, localizações e números novos são candidatos para avaliação.

O mapa atual, população fixa de 480, malhas e animações existentes são mantidos. A H01 conserva o adaptador anterior do inventário C-05. Os personagens permanecem estacionários, sem combate humano ou troca. Os outros seis personagens ainda não têm encontros físicos.

Verificação isolada:

```powershell
godot --headless --path . --script res://personagem/qa_social_model103.gd
godot --path . -- --qa-demo95 --characters103-test
godot --path . -- --qa-demo95 --characters103-test --characters103-reopen
```

Os dois últimos comandos usam o mapa real e gravam somente sob `qa/characters103/`. O teste de migração utiliza `personagem/fixtures103/legacy102.json`, uma cópia do checkpoint de QA R102. O perfil normal segue `user://demo_population_r98.json`. Relatório e capturas em `docs/dialogo_r103/` na raiz do workspace.
