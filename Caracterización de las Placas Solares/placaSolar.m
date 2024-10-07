clear;
close all;

%Valor de la resistencia usada
R = 680; % +- 5%. Mirado en internet con el código de colores 

%Paso de ángulo y número de medidas tomadas
angulos = 0:15:180;
medidas = 1000;

%Matriz donde almacenamos todos los voltajes
voltajes = zeros (medidas, length(angulos));

%Cargamos todos los vectores de datos
for i = 0:15:180
    fichero = sprintf('Voltaje_%d.txt', i);
    load(fichero);
    voltajes(:, (i/15)+1) = eval(sprintf('Voltaje_%d', i));
end

%Histogramas de voltajes para cada vector
figure;
hold on;
for j = 1:13
    histogram(voltajes(:,j), 20)
end
title('Voltaje cada 15º con R=680Ω', 'FontSize', 20);
xlabel("Rango de Voltaje (V)", 'FontSize', 18);
ylabel("Número de datos", 'FontSize', 18);
legend({'0', '15', '30', '45', '60', '75', '90', '105', '120', '135', '150', '165', '180'}, 'FontSize', 14);
grid on;

%% Calculamos la media y la desviación típica de cada vector
medias = zeros(1,13);
medianas = zeros(1,13);
des_tip = zeros(1,13);

for i = 1:13
    medias(i) = mean(voltajes(:,i));
    medianas(i) = median(voltajes(:,i));
    des_tip(i) = std(voltajes(:,i));
end

%{
Lo hacemos con Boxplot
%Grafica de las medias y desviaciones típìcas con plot
figure;
hold on;

% Rellena el área entre las líneas punteadas
fill([angulos, fliplr(angulos)], [medias-des_tip, fliplr(medias+des_tip)], 'b', 'FaceAlpha', 0.1, 'LineStyle', '--');
    % si hacemos [angulos,angulos] obtenemos un vector que va de
    % 0...180,0...180. Para dibujar el área necesitamos acabar donde
    % empezamos. Con fliplr damos la vuelta a la segunda parte


%errorbar(angulos, medias, des_tip, 'LineStyle', '-', 'LineWidth', 1 , 'Marker', '*', 'MarkerEdgeColor', 'r', 'MarkerSize', 10);

%Medias
plot(angulos, medias, 'LineStyle', '-', 'LineWidth', 1, 'Marker', '*', 'MarkerEdgeColor', 'r', 'MarkerSize', 10);

%Desviaciones típicas
for i = 1:length(angulos)
    % Dibuja el punto de la media - desviación típica
    plot(angulos(i), medias(i)-des_tip(i), 'g.', 'MarkerSize', 20); % Punto verda
    
    % Dibuja el punto de la media + desviación típica
    plot(angulos(i), medias(i)+des_tip(i), 'm.', 'MarkerSize', 20); % Punto verde
    
    % Dibuja la línea que une los valores de las desviaciones típicas con un color específico
    plot([angulos(i), angulos(i)], [medias(i)-des_tip(i), medias(i)+des_tip(i)], 'k-', 'LineWidth', 1); % Línea negra
end
%}

% Graficamos un boxplot
figure;
boxplot(voltajes, angulos);

xlabel('Ángulo (grados)', 'FontSize', 18);
ylabel('Voltaje (V)', 'FontSize', 18);
title('Medianas y cuartiles de los voltajes para diferentes ángulos', 'FontSize', 20);
grid on;


%% Plot de los voltajes

for i=0:15:180
    figure;
    plot(voltajes(:,(i/15)+1),'.-')
    title(sprintf('Voltaje %dº con R=680Ω', i), 'FontSize', 20);
    xlabel("Número de medidas", 'FontSize', 18);
    ylabel("Rango de Voltaje (V)", 'FontSize', 18);
    grid on;
end


%% En la gráfica de las medias y desviaciones típicas veíamos que nuestro modelo no es lineal por lo que vamos a tener que suponer que lo es.

figure;
plot(angulos(1:7)*(pi/180),medianas(1:7), '.-'); % Las medianas son los voltajes para ese ángulo concreto
xlabel("Ángulos (rad)", 'FontSize', 18);
ylabel("Voltaje (V)", 'FontSize', 18);
title("Aproximación Lineal", 'FontSize', 20)
grid on;

% y = -0.3992x + 0.6136 -> si y = 0 -> x = 1.5370 * 180/pi = 88.068

figure;
% Como teniamos una gráfica decreciente la invertimos para que sea
% creciente con el objetivo de eliminar el termino independiente
plot((88.068-angulos(1:7))*(pi/180),medianas(1:7), '.-');
xlabel("Ángulos (rad)", 'FontSize', 18);
ylabel("Voltaje (V)", 'FontSize', 18);
title("Aproximación Lineal", 'FontSize', 20)
grid on;

% La ecuación de la recta que estamos obteniendo es y = 0.3992x + 1.203e^-06 
% Necesitamos hacer una regresión lineal para que la recta pase por el
% origen, poder calcular la nueva pendiente y de hay sacar la nueva TF.

x = (88.068-angulos(1:7))*(pi/180);
y = medianas(1:7);

% Realizar el ajuste lineal usando polyfit
p1 = polyfit(x, y, 1); % 1 indica un ajuste lineal

y1 = polyval(p1, x);

% Calculamos la pendiente eliminando el termino independiente
m_regresion = sum(x.*y) / sum(x.^2); % y = mx -> Ya tenemos la ecuación de la recta sin termino independiente de aquí podemos sacar la TF
%La pendiente es diferente pero a partir del 5 decimal

% Ecuacion de la recta sin intercepto
p2 = [m_regresion 0];  

y2 = polyval(p2, x);

% Graficar los datos y la recta de regresión sin término independiente
figure;
plot(x, y1, '-o'); % Datos originales
hold on;
plot(x, y2, '.-'); % Recta de regresión sin término independiente
xlabel("Ángulos (rad)", 'FontSize', 18);
ylabel("Voltaje (V)", 'FontSize', 18);
title('Regresión Lineal sin término independiente', 'FontSize', 18);
legend('Datos originales', 'Recta de regresión sin término independiente', 'FontSize', 14);
grid on;
hold off;

% Otra manera de forzar que la regresión lineal pase por cero
dlm = fitlm(x,y2,'Intercept',false);
figure;
plot(dlm);
grid on;


%% Apartado de futuras mejoras, voltaje desde 0º a 360º de una sola placa

% Reflejar los datos para crear la parte izquierda de la campana
angulos_invertidos = -flip(angulos(1:7));  % Invertir los ángulos y cambiar signo
medianas_invertidas = flip(medianas(1:7));  % Invertir los voltajes

% Combinar los datos para formar la campana
angulos_completos = [angulos_invertidos, angulos(1:7)];
medianas_completas = [medianas_invertidas, medianas(1:7)];

% Convertir los ángulos a radianes
angulos_completos_rad = angulos_completos * (pi / 180);

% Grafica de los datos
figure;
plot(angulos_completos_rad, medianas_completas, '.-');
xlabel("Ángulos (rad)", 'FontSize', 18);
ylabel("Voltaje (V)", 'FontSize', 18);
title("Voltajes para los ángulos de 0º a 360º", 'FontSize', 20);
grid on;


