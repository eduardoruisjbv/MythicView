# Mythic View — Changelog

## 2.0.0 — Lançamento da integração de combate (2026-10-10)

### Adicionado

- Integração do mouse look, reticle targeting, crosshair, click casting, Auto Unlock e Ally Cycle nas páginas de configurações do Mythic View.
- Controles nativos do WoW para vínculos de teclas, cores de reação e configurações avançadas de targeting.
- Tags de orientação nas opções: Recommended, Optional, Not recommended e Advanced.

### Alterado

- O Mythic View agora reúne as configurações da câmera e do combate em uma interface nativa de Settings.
- Os dados do Combat Mode ficam em `MythicViewDB.combatMode`. Para migrar os dados do addon independente, execute `scripts/migrate_combatmode_sv.py` com o WoW fechado.

### Corrigido

- Inicialização do changelog do Combat Mode quando integrado ao Mythic View.
- Janelas com estilo do Combat Mode abertas pelas configurações integradas e texto cortado na legenda.

## 1.1.0 — Três novos estilos de câmera (2026-10-08)

- Adicionados **The Last of Us Part II** (baixa e colada no ombro, visão fechada, movimento lento e tenso, mira ao conjurar), **Ghost of Tsushima** (média distância, quase centralizada, transições longas e suaves) e **Sekiro: Shadows Die Twice** (mais perto e mais rápida que Elden Ring, foco forte no inimigo, impactos secos).
- Dez estilos selecionáveis no total, além da câmera PvP competitiva automática.

## 1.0.7 — Correção de carregamento Lua (2026-10-07)

- Corrigido o excesso de variáveis locais do Lua 5.1 que impedia o carregamento do addon. As funções PvP agora usam o namespace do addon e a tabela de ajustes existente, preservando a câmera PvP fixa e a troca automática.

## 1.0.6 — Câmera PvP fixa (2026-10-07)

- O modo automático de Arena/Campo de Batalha agora mantém um perfil durante combate, grupos, movimento e montaria: zoom máximo do addon, FOV de 90 graus, câmera centralizada e sem camadas dinâmicas.
- A checkbox de troca automática continua ativada por padrão; o estilo escolhido pelo jogador volta ao sair do PvP.

## 1.0.5 — Câmera PvP automática (2026-10-07)

- Adicionado o estilo PvP Competitivo, com visão mais aberta, centralizada e estável, menos movimento de câmera e sem apontar para o alvo durante a conjuração.
- Arenas e Campos de Batalha passam a usar esse estilo automaticamente. O estilo escolhido pelo jogador é restaurado ao sair do PvP; a troca automática pode ser desativada nas opções.

## 1.0.4 — Câmera de Campo de Batalha (2026-10-07)

- Adicionados enquadramentos próprios para Campos de Batalha, com perfis diferentes para combate normal, grupos e grandes aglomerações. O perfil PvP tem prioridade sobre movimento e montaria para manter a visão aberta e estável.
- O acompanhamento da câmera pelo alvo fica desativado em Campos de Batalha e Arenas, evitando que a câmera do jogo puxe o enquadramento em direção aos inimigos selecionados.

## 1.0.3 — Smooth camera (2026-10-05)

- Fixed the slight camera judder: while animating, the camera now updates on every rendered frame (up to 144 Hz). Previously, it updated at half the frame rate and reset the timer, producing uneven 2–3-frame steps.
- Profile transitions now drive zoom through the engine’s continuous movement (`MoveViewIn/Out`) at the easing curve’s velocity, instead of many short `CameraZoomIn/Out` steps, and apply a single correction when the curve ends.
- Idle cost is unchanged: when nothing is animating, the camera still updates infrequently.

The full history is in [CHANGELOG.md](CHANGELOG.md).
