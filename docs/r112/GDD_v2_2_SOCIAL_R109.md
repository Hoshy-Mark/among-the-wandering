# Entre os Andarilhos — GDD v2.2 / sistema social e progressão R109

**Estado:** revisão implementada candidata à avaliação de escrita e balanceamento. Este capítulo complementa a Bíblia v2.1; não reescreve a campanha inteira nem transforma propostas em desfechos canônicos. Data: 20/11/2026.

## 1. Fontes e precedência

1. Instruções atuais do diretor e escopo aceito no gameplay.
2. GDD Oficial v2.1 fornecido no pacote M03–M07: capítulos 6–11, 13 e 15–16; especialmente pp. 7–10.
3. Revisão narrativa dos nove personagens de Arroio, v1: biografias e vínculos estabelecidos; side quests são sugestões.
4. Implementação R105–R108, avaliada como base técnica, não como regra de design intocável.

A arte do menu R108 fica preservada. A cidade atual e a população persistente de 480 zumbis prevalecem sobre os 124 citados no documento narrativo antigo. Esta revisão não reposiciona população, não cria mortes, cura, fuga concluída, vingança ou serviço de loja. Igor permanece sem destino confirmado. A esperança do fazendeiro é uma posição atribuída, não prova de reversão da infecção. A profissão anterior de Renata não se torna pública por abrir o menu.

## 2. O que a auditoria de gameplay encontrou

A base já tinha quatro habilidades, sete testes de 2d6, 22 registros de informação, oito dimensões de relação, nove grafos, experiência por atividades únicas e persistência. Já existiam alguns desbloqueios entre personagens: Jorge → médico, Gabriel → padre, médico → Renata, Samuel → Ana. Muitos pedidos pessoais, porém, terminavam numa mesma recusa mesmo após cumprir os requisitos. As relações persistidas focavam as duas direções jogador/NPC; a camada genérica aceitava outras arestas, mas elas não tinham uma rede inicial nem interações próprias. A ficha do menu corretamente evitava mostrar dados internos, porém não tinha novas confidências com fonte para apresentar.

R109 acrescenta 19 escolhas principais, seis informações, um teste adicional e uma alternativa contextual após falha. O catálogo passa a 147 opções totais, contando retornos e nós anteriores. Estes números medem conteúdo, não prometem duração de campanha. O grafo entre os dez atores (nove habitantes e protagonista) agora contém 90 direções independentes.

## 3. Regra de disponibilidade antes de qualquer dado

A ordem obrigatória é: contexto de interação válido → informação disponível → limites e vínculos → tentativa incerta, quando houver → consequência → memória e eventual aprendizado.

- **Informação pública:** sem dado. Exemplo: perguntar a ocupação de alguém disposto a responder.
- **Informação necessária:** opção ausente até o protagonista possuir a pista. Exemplo: Ana estudou em Sorriso Feliz e Samuel voltou recentemente; os dois registros permitem perguntar a ele sobre sobreviventes ali.
- **Abertura pessoal insuficiente:** a resposta aparece bloqueada, com motivo qualitativo. Não mostrar o segredo que está por trás dela nem todos os números internos.
- **Condições cumpridas e escolha determinística:** a pessoa conta o que decidiu contar; não lançar dado por hábito. Exemplo: Ana fala de Igor depois de receber o contexto de Sorriso e construir confiança.
- **Resultado realmente incerto:** usar o teste definido para aquela abordagem. Exemplo: tentar criar espaço de escuta com Gabriel usa Empatia; falha pode encerrar aquela abordagem sem encerrar toda a conversa.
- **Limite resistente:** rolagem alta não substitui consentimento, informação, memória de violência ou condições materiais. Nem todo assunto tem uma tentativa disponível.

O menu só consome a projeção do conhecimento; abrir uma aba não aumenta confiança, não concede informações e não faz uma aliança aparecer.

## 4. Habilidades e dado

Mantêm-se **Persuasão, Percepção, Empatia e Intimidação**, níveis 0–6. Há oito definições de teste no catálogo atual. A regra é 2d6 + habilidade + modificadores autorais versus dificuldade. Dois uns falham; dois seis têm sucesso apenas depois que as condições de acesso foram satisfeitas. A interface informa a chance calculada sobre os 36 resultados; a produção não força a rolagem favorável.

Dificuldade e modificadores não são calibrados como uma soma de “amizade total”. Quem respeitou limites pode melhorar as condições; quem conhece um documento pode ter um assunto novo, mas isso não autoriza revelação privada universal. Cada teste define se é único ou se permite nova tentativa com contexto melhor. Resultado, dados, contexto e estado do RNG são salvos. Fechar e reabrir a conversa não rerrola.

**Decisão desta revisão:** não acrescentar habilidades apenas para aumentar a lista. As quatro já cobrem as abordagens sociais implementadas. Novas habilidades devem ter pelo menos três usos distintos, consequências diferentes e caminhos alternativos; não podem duplicar Empatia/Persuasão. Medicina, investigação material, negociação de recursos e liderança podem ser avaliadas quando seus sistemas concretos oferecerem esses usos. Não estão liberadas como habilidades ficticiamente funcionais no menu atual.

Os NPCs têm as mesmas quatro habilidades, com valores próprios persistidos. A interação genérica de escuta usa a Empatia do iniciador e a mesma regra de 2d6. Atribuir automaticamente aumentos de habilidade a agendas de NPC não faz parte da R109; será necessário definir escolhas e interesses de treinamento por personagem.

## 5. Experiência e investimento

Preserva-se a regra existente: três experiências únicas concedem um ponto; melhorar uma habilidade custa um ponto. Repetições não rendem nada e nível máximo não consome ponto. Uma tentativa relevante pode ensinar mesmo na falha.

Os 30 IDs de atividade anteriores permanecem para não invalidar investimentos de campanhas já salvas. A R109 acrescenta **sete** IDs: seis descobertas novas e a tentativa de escuta com Gabriel. As outras novas respostas, inclusive cortesia e desescalada, não rendem experiência. Assim, as 37 atividades atuais permitem no máximo 12 pontos, sujeitos à disponibilidade dos caminhos, e não permitem maximizar automaticamente todas as quatro habilidades iniciais de nível 2 (seriam necessários 16 pontos). Falas pessoais não viram um gerador ilimitado de confiança ou experiência.

Os pontos do protagonista não são globais. Um encontro entre NPCs não lhe dá XP, não muda seus atributos e não aumenta a confiança de todos na cidade. Uma futura revisão das recompensas antigas deve migrar o saldo gasto explicitamente; não retirar pontos já usados silenciosamente.

## 6. Relações: seis eixos centrais e quatro condições de apoio

| Eixo central | Uso | Não implica |
|---|---|---|
| Amizade (`affection`) | afeto e vontade de convivência | confiança ou aliança |
| Confiança (`trust`) | segurança e credibilidade para aquele interlocutor | concordância moral |
| Respeito (`respect`) | reconhecimento de postura e capacidade | carinho |
| Medo (`fear`) | expectativa de ameaça ou dano | lealdade ou consentimento |
| Ressentimento (`resentment`) | ofensas e perdas lembradas | agressão imediata obrigatória |
| Romance (`romance`) | interesse afetivo contextual | consentimento ou reciprocidade |

Dependência, obrigação, cooperação e intimidade permanecem como quatro condições de apoio, separadas dos seis eixos centrais. Os intervalos técnicos são de -100 a 100 nos eixos que já permitiam oposição e de 0 a 100 nos demais. São unidades internas; não porcentagens de amizade.

Para o começo da demo, confiança 1 representa cortesia inicial, 2 abertura limitada, 3 uma confidência contextual e 4 uma abertura mais exigente. Esses limiares pequenos pertencem ao trecho inicial, no qual os encontros rendem valores discretos; não representam confiança profunda ou amizade plena na campanha longa. Pontuações antigas foram preservadas. Os valores maiores entre moradores representam história prévia e são parâmetros de balanceamento candidatos, não uma medição objetiva das biografias.

**A→B é diferente de B→A.** Um evento só altera a direção e dimensões declaradas. Uma alteração na confiança de Renata no médico não altera automaticamente a confiança dele nela. Família, casamento, coerção, ruptura e acordos são estados qualitativos distintos. Amizade alta não cria a tag `ally`; um casamento coercitivo não cria consentimento.

Foram configuradas 18 direções iniciais baseadas nos vínculos narrativos. Exemplos: Renata/médico e Renata/Ana têm proximidade recíproca assimétrica; Gabriel teme Jorge, mas Jorge não tem o mesmo medo; Pietra tem ressentimento e desconfiança duradouros do irmão e do fazendeiro; Josué teme Pietra; Samuel e Gabriel têm uma história afetiva, sem isso autorizar romance atual automático. Relações sem caracterização recebem um ponto inicial técnico neutro, oculto ao jogador, sem afirmar que os personagens se amam ou se conhecem profundamente.

## 7. Conhecimento, relato e verdade

A lista de informações possui um registro por receptor. Cada aquisição nova guarda fonte, canal, natureza do registro e evento. Um relato recebido continua sendo relato; não vira verdade do mundo por ter passado de uma pessoa para outra. A crença no poder da cura não comprova uma cura; a falta de notícias de Igor não confirma sua morte.

As fontes canônicas iniciais permanecem separadas das descobertas do protagonista. Informações antigas migradas sem uma fonte comprovável são marcadas como registro legado, sem inventar um interlocutor. Informações recebidas na conversa registram o falante real.

O domínio permite transmissão **pública** entre NPCs quando o emissor conhece a informação, o receptor ainda não a possui e não rejeita a credibilidade daquela fonte pela confiança direcionada. O resultado fica como informação relatada. Não há broadcast, contágio automático por facção ou efeito sobre quem não participou. O coordenador do mapa exige proximidade, visibilidade e linha de visão antes de autorizar a troca. Segredos não são transmitidos por esse mecanismo; exigem escolhas autorais de revelação.

A interpretação e crenças completas, versões conflitantes e retratação ainda precisam de evolução além desse registro de proveniência. Não foi implementado um classificador onisciente que diga ao jogador quem está mentindo.

## 8. Cadeias jogáveis desta entrega

### Ana, Samuel e Renata: investigação e confiança sem dado obrigatório

1. Ana informa onde estudava. Isso não revela Igor.
2. Samuel conta que voltou a Arroio. Com esses dois registros, surge a pergunta sobre sobreviventes em Sorriso Feliz.
3. Samuel relata que há sobreviventes. A fala identifica o limite do seu conhecimento.
4. Em Ana, aparece o assunto pessoal relacionado à esperança, ainda bloqueado por confiança insuficiente.
5. Respeitar espaço e ouvir sem exigir detalhes são atos únicos; sozinhos ainda não bastam.
6. Renata, após abertura limitada, fala da proximidade com Ana. Esse registro abre outra fala com Ana e completa um contexto de confiança mais consistente.
7. Ana pode contar sobre Igor. Não há dado nessa revelação, nem promessa de resgate, nem confirmação de destino.

### Médico e Renata: informação pública antes de cuidado pessoal

Conhecer o médico abre uma fala com Renata; ela pode revelar o casamento. Saber desse vínculo abre um assunto com o médico, mas ele exige confiança 3 e intimidade 1. Privacidade respeitada e escuta ajudam; a abordagem de Empatia anterior continua sendo uma tentativa incerta. Só então ele relata que cuida da esposa doente. A fala não cria missão, entrega de doses ou relógio de morte.

### Samuel e Gabriel: não decidir pela pessoa

Saber quem é Gabriel, somado à confiança 3 e intimidade 1 com Samuel, permite receber o relato de uma confidência. Gabriel não se torna aliado automaticamente. Para confirmar pessoalmente, ele exige confiança 4, intimidade 2 e contexto coerente com sua falta de confiança em Jorge. A confirmação não define fuga, confronto ou dependência do jogador.

A tentativa de escuta com Empatia pode falhar. A falha deixa memória e não pode ser rerrolada. Descobrir depois a confidência, respeitar limites e aceitar que Gabriel controle a conversa oferece outra aproximação determinística. Essa alternativa tem requisitos próprios; não transforma a falha anterior em sucesso retroativo.

### Pietra, Josué, Jorge e fazendeiro

Informação de parentesco abre a confirmação com Josué; ele não recebe autorização para falar por Pietra. Conversas sobre ervas respeitam os limites dela e não revelam veneno ou plano de vingança. A participação do médico no confinamento abre comentários distintos com Jorge e com o fazendeiro. Eles não recebem conhecimento dos crimes uns dos outros por esse caminho.

Intimidar Jorge pode deixá-lo mais ressentido mesmo quando ele escuta. Uma falha abre a possibilidade de baixar o tom depois de conhecer as regras; a desescalada reduz parte do ressentimento, mas não apaga a memória da ameaça. Não é uma forma repetível de obter XP.

## 9. NPCs entre si no mapa atual

O mesmo modelo tem direção, memória, vínculo qualitativo, conhecimento e atributos para todos os nove habitantes. Cumprimento cortês é recusado quando confiança, medo ou ressentimento inviabilizam a aproximação. Uma tentativa incerta de escuta usa o atributo do NPC iniciador e grava a rolagem; não usa a ficha do jogador.

O coordenador atual executa um piloto de conversa próxima entre Renata e o médico, a cada verificação de contexto de 20 segundos, com eventos únicos por direção. Eles precisam estar a até 4 m, presentes e com linha de visão. Há cuidado cotidiano e transmissão de um relato público do médico sobre sua participação no confinamento. O receptor pode conhecer esse relato sem que o jogador o receba. Um observador próximo pode perceber que conversaram, sem ganhar o assunto privado por telepatia.

Este é um piloto de autonomia social, não nove agendas diárias completas. Os NPCs continuam nos encontros estacionários atuais; a R109 não implementa busca de recursos, combate humano, romance jogável, traições automáticas, rotas diárias ou resolução de arcos fora da tela. O serviço genérico já aceita qualquer par válido; novos contextos precisam ser escritos e ligados a encontros reais.

## 10. Memória e persistência

O bloco `social109` é acrescentado ao snapshot `social101` que a campanha já salva. Contém atributos dos NPCs, proveniência das informações, vínculos qualitativos, eventos únicos, memórias por participante e resultados de dados dos NPCs. As 90 relações ficam no grafo direcional existente.

A migração de R105–R108 preserva nível, saldo gasto, RNG, tentativas, descobertas do protagonista e relações antigas. Somente personagens que canonicamente detêm informações novas recebem seus registros iniciais. O jogador não ganha segredos por atualizar a versão. O mapa, equipamentos, munição e organização manual do inventário usam os serviços existentes.

## 11. Critérios para o próximo bloco

- Escrever novas consequências sociais por conhecimento recebido, evitando reputação global.
- Acrescentar versões conflitantes, grau de crença e retratações com fonte e memória, antes de expor avaliações numéricas na ficha.
- Vincular agendas e interações NPC/NPC a recursos, interesses e passagem do tempo real do mundo; ampliar o piloto sem teleportar interlocutores.
- Criar acordos com condições e ruptura explícitas. Não deduzir lealdade ou aliança de barras.
- Integrar testemunhos de violência e atos físicos somente com observadores válidos.
- Avaliar habilidades adicionais quando houver sistemas concretos e usos suficientes. Preservar o princípio de que nenhuma habilidade ignora todos os limites.
- Testar uma rota de êxito e uma de falha para cada cadeia; garantir alternativas sem tornar todos os caminhos possíveis na mesma campanha.

As próximas cenas, limiares e direções de equilíbrio exigem avaliação do diretor. As propostas de quests da narrativa antiga seguem sem promoção automática a cânone.
