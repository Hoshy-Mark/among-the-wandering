# R116 — tiros próximos, braços e atalhos do inventário

Atualizado em 21 de novembro de 2026. Humanos continuam protegidos, conforme a confirmação do diretor. Os nove personagens e as 480 identidades de zumbis são preservados.

## Entrega

| Problema | Correção |
|---|---|
| Tiros bloqueados contra zumbis próximos | O alvo vivo na trajetória deixa de ser tratado como parede junto ao cano. A trajetória curta até a boca da arma também é verificada, respeitando o primeiro obstáculo. |
| Braços deformando após repetir a mira e caminhar | Os ossos principais dos braços deixam de herdar escala residual do ajuste procedural. As poses capturadas e o solver mantêm bases rígidas, preservando os suportes de cotovelo/punho e a malha aprovada. |
| Pegar itens exigia escolher uma célula | Clique simples ou F sobre o item externo tenta guardá-lo em espaço livre da mochila; sem mochila equipada, tenta os bolsos. |
| Equipar exigia procurar o botão | E equipa o objeto sob o cursor ou selecionado, usando a transação de equipamento existente. |

O arraste manual continua escolhendo a célula e a orientação. O clique é reconhecido na soltura do botão, enquanto ultrapassar o limiar de arraste mantém a operação manual. Objetos já guardados não são reorganizados. Mochila cheia, objeto grande demais, fonte fechada ou fora de alcance recusam a transferência sem apagar ou duplicar itens. A coleta por clique/F é imediata; equipar mantém o gesto e a confirmação existentes. Não foram alterados o layout C-05, os atalhos de armas, a regra de munição ou o formato dos saves.

## Causa confirmada dos tiros

Na R115, o teste de cano obstruído recusava disparos com o zumbi a 0,6 e 0,9 m: o alvo anatômico era interpretado como obstáculo junto à arma. A 1,2 m ou mais, o mesmo disparo funcionava. A correção distingue o alvo de combate do obstáculo do cenário. O alinhamento visual usa um alvo à frente quando o inimigo encosta no cano, evitando torcer o punho para trás. Isso não altera a mira balística para escolher automaticamente um inimigo.

Os testes confirmaram dano e consumo de uma única bala a 0,6 / 0,9 / 1,2 / 3,0 m. Uma parede continua interceptando o tiro. Um humano continua bloqueando a trajetória sem receber dano e sem permitir atingir o zumbi atrás dele.

## Causa confirmada dos braços

Alguns clipes possuem rotação e posição dos braços, mas não trilhas de escala. As bases produzidas pelo ajuste procedural e reutilizadas em transições podiam deixar escala/cisalhamento residual para o próximo clipe. Na reprodução antiga de 80 ciclos, o desvio máximo de comprimento de um eixo chegou a 1.181 em relação à escala unitária.

Na revisão, a amostragem redefine a escala dos ossos principais, as capturas da saída da mira usam bases ortonormais e o solver não grava escala incidental. Os ossos auxiliares que sustentam o volume das dobras continuam com seu tratamento anterior. Nenhuma geometria, roupa, mão ou coreografia foi substituída.

Foram executados 90 ciclos com pistola em passos de 30/60/120 Hz e mais 30 com revólver e 30 com arma longa. O desvio máximo de escala ficou em 0.000000536; as distâncias máximas das costuras foram 22.03 mm no cotovelo e 3.79 mm no punho, dentro dos limites da base aprovada.

## Verificação

- 208 verificações nativas R116 aprovadas: acesso físico aos móveis, clique/F/E, mochila sem espaço, fonte fechada, ausência de duplicação, células escolhidas por arraste, 150 ciclos de mira, disparo próximo, humano protegido e parede.
- Mais 100 verificações de portas/janelas, seis de cercas/obstrução/cancelamento e cinco de salvar/carregar, incluindo campanha R112, aprovadas.
- Perfis de teste próprios em `qa/r116/`; o perfil pessoal do jogador não foi usado.
- Quatro capturas reais em JPEG, cada uma abaixo de 210 KB, adequadas à revisão remota.

A primeira passagem da regressão de salvamento encontrou um erro na preparação do teste: a atualização dos móveis estava congelada durante o fechamento de um armário. O teste passou a aguardar os endpoints físicos antes da regressão. A guarda de salvamento do jogo foi preservada; ela continua recusando móveis em movimento.

## Otimização durante a mira

`_solid` agora aplica as mudanças de visibilidade na mudança de estado, evitando repetir a mesma varredura de etiquetas, parâmetros e restauração do interior a cada quadro da mira. A atualização normal dos controladores permanece ativa.

Na comparação curta de oito segundos a 1280×720, com Compatibility e sem VSync/limite de FPS somente no teste, a variante com trabalho repetido registrou 63.7 FPS e a revisão 66.4 FPS. Uma amostra anterior da variante repetida havia registrado 68,3 FPS. A variação não sustenta afirmar um ganho consistente de FPS neste lote. Ambas as variantes recentes desenharam 1.733 chamadas e 8.082.172 primitivas, no mesmo ponto e com zero avatares de zumbis ativos; as 480 identidades continuam na simulação.

O benchmark isola somente a rotina de visibilidade; as correções de braços e disparo ficam ativas em ambas as variantes. Os números da R115 em visão isométrica são outro cenário e não devem ser comparados diretamente a esta câmera de ombro. Vegetação, sombras, agrupamento espacial e carga por região continuam sendo os próximos alvos de otimização.

## Repetir

Após importar o projeto no Godot 4.4.1 Standard, execute cada comando separadamente:

```text
godot --path . --script res://tests/review116.gd
godot --path . --script res://tests/diagnostic116.gd -- --baseline116
godot --path . --script res://tests/diagnostic116.gd
godot --path . --script res://tests/performance116.gd -- --uncached116
godot --path . --script res://tests/performance116.gd
```

O diagnóstico de baseline injeta os cinco scripts R115 preservados em `tests/fixtures116/` apenas na memória do processo. Os arquivos do runtime não são reescritos. O teste de desempenho injeta somente a antiga função `_solid`, para comparar seu custo mantendo as demais correções iguais. As capturas de revisão usam atores controlados para repetir as condições; o comportamento normal da IA não foi desativado no jogo entregue.
