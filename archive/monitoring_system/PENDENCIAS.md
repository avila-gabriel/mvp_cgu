# Pendências

## Perguntas para a CGU

1. Em qual navegador a equipe usa o fluxo de avaliação no `Fala.BR` / `STA`?
2. A equipe possui domínio e servidor para hospedar a solução?
3. Qual é o número máximo esperado de revisores simultâneos?

## Materiais Necessários

1. HTML da página do `Fala.BR` / `STA` que contém o botão de submissão da
   avaliação.
2. Exemplos reais de URLs públicas informadas em itens avaliados e seus itens correspondentes.

## Ações Após Receber os Materiais

1. Confirmar o ponto correto de captura na página de avaliação.
2. Revisar os placeholders em `extension/manifest.json`.
3. Revisar `extension/src/extension.gleam`, incluindo `target_form_id`,
   `target_form_action`, `forward_url` e `error_url`.
4. Revisar os endpoints de ingestão no servidor.
5. Como transformar as definições do GTA em detectores por item.
