# R104 — Jorge, Ricardo Medeiro e quatro habilidades

Execute a cena padrão do projeto na Godot 4.4.1. Cinco identidades têm encontros conversáveis: Samuel na P01; Gabriel e Josué na fachada da igreja EST01; Jorge em outro ponto da P01; Ricardo Medeiro na fachada externa da farmácia EST07. Os pontos são provisórios, sem definir residências ou serviços.

E conversa, clique ou números/Enter respondem, Esc encerra; P abre habilidades fora da conversa. I/H preservam inventário/corpo, e setas/1–4 continuam armas fora das interfaces.

Ouvir a orientação de Jorge sobre os infectados abre um assunto com o médico sobre sua participação no confinamento. Intimidação e Empatia têm agora usos próprios e podem receber pontos. Uma tentativa única não se reabre após treino. Relações são individuais; conhecimento e aprendizado do jogador persistem entre conversas. Confiança negativa aparece como abalada no cabeçalho.

As falas, aparências, efeitos e locais novos são candidatos para avaliação. Não foram implementados fiscalização/punição, atendimento médico, venda de medicamentos ou revelações/quests privadas. Os atores continuam estacionários.

```powershell
godot --headless --path . --script res://personagem/qa_social_model104.gd
godot --path . -- --qa-demo95 --characters104-test
godot --path . -- --qa-demo95 --characters104-test --characters104-reopen
```

O QA salva somente sob `qa/characters104/`; a migração usa `personagem/fixtures104/legacy103.json`, um checkpoint de QA R103. O perfil normal permanece `user://demo_population_r98.json`. Capturas e relatório em `docs/dialogo_r104/` na raiz do workspace. O mapa atual e os 480 zumbis foram preservados; a H01 continua com o adaptador anterior do C-05.
