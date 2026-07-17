# Wireframe da página inicial

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ VELYRA       Início   Pesquisar   Biblioteca   Addons   Definições          │
│                         barra Liquid Glass flutuante                         │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  HERO CINEMATOGRÁFICO                                                        │
│  imagem/vídeo silencioso                                                     │
│                                                                              │
│  DESTAQUE VELYRA                                                             │
│  Título                                                                      │
│  metadata · classificação · ano                                              │
│  descrição acessível                                                         │
│  [▶ Reproduzir] [ⓘ Detalhes]                                                 │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ Continuar a ver                                                              │
│ [episódio + progresso] [filme + progresso] [episódio + progresso]           │
├──────────────────────────────────────────────────────────────────────────────┤
│ Explorar por género                                                          │
│ [Ação] [Comédia] [Drama] [Ficção científica] [Thriller] [Animação]          │
├──────────────────────────────────────────────────────────────────────────────┤
│ Explorar por streaming · Portugal                                            │
│ [Netflix] [Disney+] [Prime Video] [Max] [Apple TV+] [SkyShowtime]            │
├──────────────────────────────────────────────────────────────────────────────┤
│ Resultado do filtro selecionado                                              │
│ [poster] [poster] [poster] [poster] [poster]                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ Séries em tendência                                                          │
│ [poster] [poster] [poster] [poster] [poster]                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ Filmes em tendência                                                          │
│ [poster] [poster] [poster] [poster] [poster]                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ Top 10 Velyra de séries · Portugal                                           │
│ [1 poster] [2 poster] [3 poster] ...                                         │
├──────────────────────────────────────────────────────────────────────────────┤
│ Top 10 Velyra de filmes · Portugal                                           │
│ [1 poster] [2 poster] [3 poster] ...                                         │
├──────────────────────────────────────────────────────────────────────────────┤
│ Coleções por serviço                                                         │
│ Na Netflix · No Disney+ · No Prime Video                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│ Dados TMDB e JustWatch · Concebida em Portugal                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Comportamento do foco

- O primeiro foco da Home é a ação Reproduzir do hero.
- Ao descer, o foco entra no primeiro item da secção seguinte.
- Ao regressar a uma secção, o último item focado deve ser restaurado.
- Os cartões ganham escala reduzida, contorno e profundidade; nunca dependem só de cor.
- O scroll vertical deve acompanhar a mudança de secção, sem saltos bruscos.
- Com Reduzir Movimento, não existe escala nem parallax; mantém-se apenas o contorno.
