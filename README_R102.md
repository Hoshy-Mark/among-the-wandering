# R102 — Aprendizado de diálogo

Abra `project.godot` na Godot 4.4.1 e execute a cena padrão. O projeto usa o mapa atual de Arroio do laboratório `e06_arroio`. A H01 mantém o adaptador legado de inventário; a migração completa dessa casa ainda está pendente.

- E conversa com Samuel no encontro público provisório da praça P01.
- Três experiências sociais distintas concedem um ponto. Perguntas repetidas e novas tentativas do mesmo teste não duplicam crédito.
- P ou o botão Habilidades abre o painel fora de ações e conversas. Cada ponto aumenta Persuasão ou Percepção em um nível, até seis. P/Esc fecha; I/H passa ao inventário/corpo.
- Uma habilidade relevante melhorada pode reabrir uma falha elegível. Os dados e resultados anteriores permanecem gravados.
- O mundo continua ativo. Dano fecha o painel.
- Salvar/carregar são os comandos existentes. Saves R101 mantêm seus níveis e recebem crédito único das atividades registradas; saves anteriores não ganham histórico inventado.

Configuração candidata em `personagem/aprendizado102.json`. Apenas quatro experiências estão escritas no diálogo atual, suficientes para um ponto e uma experiência restante. Os outros personagens e habilidades aguardam conteúdo autoral.

Malhas, animações, roupas, população fixa, inventário C-05 e HUD de armas R01 não foram modificados por esta revisão. Os números de armas 1–4 e as setas continuam disponíveis fora das interfaces.

Testes isolados:

```powershell
godot --headless --path . --script res://personagem/qa_learning_model102.gd
godot --path . -- --qa-demo95 --learning102-test
godot --path . -- --qa-demo95 --learning102-test --learning102-reopen
```

O segundo teste produz capturas e um checkpoint sob `qa/learning102/`; o terceiro retoma esse checkpoint em outro processo. Ambos usam o modo de verificação para proteger o perfil normal. Relatório e capturas: `docs/dialogo_r102/` na raiz do workspace.
