# MythicView 1.0.1 — restaurado

A atualização de desempenho 1.0.2 foi revertida a pedido do usuário. Código de câmera, distância de visão e limites de atualização restaurados do backup anterior.


## 1.0.2 — zoom nativo

O zoom deixou de ser um laço fechado (MoveViewIn/Out comparando com GetCameraZoom a cada frame), que causava tremor com a câmera parada. Agora usa CameraZoomIn/CameraZoomOut em malha aberta, como o DynamicCam: só envia a variação do alvo e não envia nada em repouso.
