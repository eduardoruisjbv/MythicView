# Mythic View — Changelog (português)

## 1.0.3 — Câmera suave (2026-10-05)

- Corrigida a pequena tremida da câmera: enquanto anima, ela agora atualiza a cada frame renderizado (limite de 144 Hz). Antes atualizava a metade da taxa de quadros e zerava o cronômetro, então andava em degraus irregulares de 2–3 frames.
- As transições de perfil conduzem o zoom com o movimento contínuo do próprio motor (MoveViewIn/Out na velocidade da curva de easing), em vez de vários pedaços pequenos de CameraZoomIn/Out, e entregam uma única correção quando a curva termina.
- O custo em repouso não mudou: sem nada animando, a câmera continua atualizando raramente.

O histórico completo (em inglês) está em CHANGELOG.md.
