clear;

close all;

%%

% Ya tenemos la TF de la planta (motor) y sensor (placas solares)

% TF sensor
H = tf(0.399208670626616, 1);

% TF planta * Integrador (1/s)
G = tf(5.395e06, [1 1.454e06 3.611e06]);

% Añadimos un integrados a la planta para convertir la velocidad del motor
% en posición y multiplicamos por el valor del sensor para hacer a este
% unitario en la rltool

G2 = G * H * tf(1, [1 0]);

rltool(G2);

polos = roots ([1 1.454e06 3.611e06 0]);