# Home e descoberta

## Objetivo

A Home da Velyra deve parecer editorial e cinematográfica, mas continuar rápida e previsível com o comando da Apple TV. O conteúdo é organizado por intenção: retomar, descobrir, filtrar e comparar.

## Ordem das áreas

1. **Hero cinematográfico** com ação principal, detalhes e backdrop/vídeo silencioso.
2. **Continuar a ver**, alimentado pelo progresso Trakt e enriquecido com imagens TMDB.
3. **Explorar por género**, através de filtros rápidos e localizados.
4. **Explorar por streaming**, mostrando apenas serviços disponíveis na região do dispositivo.
5. **Resultado contextual** do género ou serviço selecionado.
6. **Séries em tendência**.
7. **Filmes em tendência**.
8. **Top 10 Velyra de séries no país**.
9. **Top 10 Velyra de filmes no país**.
10. **Coleções por serviço**, quando houver dados suficientes.

## Fontes de dados

### Trakt

Fonte de verdade para:

- progresso de reprodução;
- continuar a ver;
- histórico;
- watchlist;
- coleção;
- scrobbling.

### TMDB

Usado para:

- metadata;
- posters e backdrops;
- tendências diárias/semanais;
- géneros;
- descoberta regional;
- fornecedores de streaming por país.

A disponibilidade de streaming devolvida pelo TMDB é alimentada pela JustWatch e deve apresentar a respetiva atribuição.

### Top 10 do país

Não existe um ranking oficial universal que agregue Netflix, Disney+, Max, Prime Video e todos os restantes serviços. Por isso, a primeira versão apresenta **Velyra Top 10**, calculado com popularidade regional, tendências e disponibilidade no país.

A aplicação nunca deve apresentar este bloco como um ranking oficial nacional. O subtítulo deve indicar que é uma seleção Velyra.

Para serviços que publiquem rankings oficiais, como o Top 10 semanal da Netflix, será criado um conector separado e a origem ficará identificada na interface.

## Regras de UX

- “Continuar a ver” só aparece quando tem conteúdo.
- A Home não deve repetir o mesmo título em secções consecutivas.
- O hero não deve repetir um item visto recentemente.
- Os filtros devem manter foco, seleção visível e leitura por VoiceOver.
- Vídeo decorativo é sempre mudo.
- Com Reduzir Movimento, o vídeo é substituído por backdrop estático.
- Com Reduzir Transparência, filtros e navegação usam superfícies sólidas.
- Cada título deve ter texto alternativo, tipo de conteúdo, ano e progresso quando aplicável.

## Cache

- Home feed: 15 minutos.
- Géneros e fornecedores: 7 dias por idioma/região.
- Imagens: cache HTTP do sistema.
- Trakt playback: atualização no arranque, regresso à app e fim de reprodução.
- Dados antigos podem ser apresentados durante uma falha de rede, com indicação discreta.

## Configuração

Adicionar ao ambiente de build:

- `TMDB_READ_ACCESS_TOKEN`
- `TRAKT_CLIENT_ID`
- `TRAKT_CLIENT_SECRET`

Segredos nunca são enviados para o iCloud.
