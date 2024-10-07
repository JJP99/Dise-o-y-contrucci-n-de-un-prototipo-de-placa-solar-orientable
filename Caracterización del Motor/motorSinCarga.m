%% Motor sin carga
%Lo que recibimos de los ficheros del encoder son los pulsos/0.1seg

clear;
close all;

%% Representación del estacionario en pulsos/0.1seg

% Número de segundos durante los que se mandan datos y número de ficheros que tenemos que leer
muestras = 100;
n_ficheros = 16; 

ppds = zeros(muestras, n_ficheros);

% Cargamos todos los vectores de datos
for i=5:5:80
    fichero = sprintf('Encoder_S%d.txt', i);
    load(fichero);
    ppds(:, (i/5)) = eval(sprintf('Encoder_S%d', i));
end

% En pulsos tenemos todos los ficheros del Encoder cuyos datos se han ido guardando aumentado el OCR0B de 5 en 5

% Gráficas por separado
%{
for i=1:n_ficheros
    figure;
    plot(pps(:,i), '.-');
    xlabel("Nº Muestras");
    ylabel("Pulsos");
    title(sprintf("Pulsos/0.1seg con OCR0B = %d",i*5));
    grid on;
end
%}

% Gráfcias juntas
figure;
hold on;
for i=1:n_ficheros
    plot(ppds(:,i), '.-');
end

xlabel("Nº Muestras", 'FontSize', 18);
ylabel("Pulsos", 'FontSize', 18);
title("Pulsos/ds incremento de 5 en OCR0B", 'FontSize', 20);
grid on;
legend({'5', '10', '15', '20', '25', '30', '35', '40', '45', '50', '60', '65', '70', '75', '80'}, 'FontSize', 14);
hold off;

%% Gráfica en segundos y velocidad angular

% Número de vuelta por revolución y gear ratio
CPR = 16;
reductora = 150;
timer = 0.1; % Timer de 0,1 segundo usado en el Arduino

% Duracion del experimento (10seg)
t_experimento = muestras * timer; 

% Vector de tiempo en segundos para el eje X
t_sim = linspace(0, t_experimento, muestras);

% Convertimos los pulsos/0.1s a rps
rps = (10 * ppds) / (CPR * reductora);

% Una vez tenemos las rps convertimos a la velocidad angular
vel_ang = rps * 2*pi;

% Gráficas por separado de la vel_ang
%{
for i=1:n_ficheros
    figure;
    plot(t_sim, vel_ang(:,i), '.-');
    xlabel("Tiempo de muestreo(s)");
    ylabel("Velocidad Angular (rad/s)");
    title(sprintf("Velocidad Angular con OCR0B = %d",i*5));
    grid on;
end
%}

% Gráfcias juntas de la vel_ang
figure;
hold on;
for i=1:n_ficheros
    plot(t_sim, vel_ang(:,i), '.-');
end

xlabel("Tiempo de muestreo(s)", "FontSize", 18);
ylabel("Velocidad Angular (rad/s)", "FontSize", 18);
title("Velocidad Angular incremento de 5 en OCR0B", "FontSize", 20);
grid on;
legend({'5', '10', '15', '20', '25', '30', '35', '40', '45', '50', '60', '65', '70', '75', '80'}, "FontSize", 14)
hold off;

%% Caracterización del sistema

% Calcular el ancho positivo para cada duty cycle
FCPU = 16*10^6;                     % Frecuencia microcontrolador
preescalado = 1;                    % Preescalado usado en la PWM
periodo = 10^5;                     % Periodo de la señal
periodoPWM = (1/periodo) * 10^9;    % 100000 Nanosegundos

pre_scaled_clock_period = preescalado / FCPU;
OCR0B = zeros(1,16);

for i=5:5:80
    OCR0B(i/5) = i;
end

anchoPositivo = zeros(1,16);

for i=1:length(OCR0B)
    anchoPositivoPWM = (2*OCR0B(i)*pre_scaled_clock_period) * 10^9;     % 625 Nanosegundos
    porcentajeAltoPWM = (anchoPositivoPWM / periodoPWM) * 100;          % Resultado en %
    anchoPositivo(i) = porcentajeAltoPWM/100;
end

% En la variable anchoPositivo tengo almacenado el ancho positivo en tiempo
% para cada OCR0B, vamos a calcular el voltaje que recibe el motor durante 
% el experimento, este vector debe tener la misma longitud que la vel_ang 
% (vol = entrada y vel = salida) 
vol_OCR0B = zeros (length(vel_ang(:,1)),16);

% Para ello sabemos que el voltaje que se le da al motor es de 12V y que a
% demas estamos usado PWM con diferentes duty cycle, esto nos indicara
% durante cuanto tiempo esta en alto la señal, de esta manera obtenemos el
% voltaje de la curva
voltaje = 12;

% Los 10 primeros valores (1seg) son los que pasa el motor parado
for i=1:length(anchoPositivo)
    vol_OCR0B(11:end,i) = voltaje * anchoPositivo(i);
end

% Creamos los objetos de datos de identificación haciendo uso de la entrada,
% salida y tiempo de muestreo para cada OCR0B -> Datos experimentales
data = cell(1,16);

for i=1:length(data)
    data{i} = iddata(vel_ang(:,i), vol_OCR0B(:,i), timer);   % Salida, entrada, tiempo de muestreo
end

% A tfest hay que proporcionarle un objeto data (entradas y salidas del
% sistema y además especificarle el orden del modelo que estamos intentando
% identificar (número de polos y ceros). Este modelo, que nos dará una TF,
% habrá que comprobar si es adecuado para describir el comportamiento de
% nuestro sistema.
sys = cell(1,16);
for i=1:length(sys)
    sys{i} = tfest(data{i},2,0);      % Datos, polos, zeros -> Simulación del modelo
end

%% Comprobar TF con un step (OCR0B = 5)
% Definir el vector de tiempo para la simulación (tiempo_s)
% Simular la respuesta del sistema a una entrada paso
[y_sim, t_sim] = step(voltaje*anchoPositivo(1)*sys{1}, t_sim);

% Graficar la respuesta del sistema
figure;
plot(t_sim, vel_ang(:,1), 'b.-', t_sim, y_sim, 'r.-');
xlabel('Tiempo (s)');
ylabel('Velocidad Angular (rad/s)');
legend('Datos Experimentales', 'Simulación del Modelo');
title('Comparación entre Datos Experimentales y Simulación del Modelo para OCR0B = 5');

%% En esta gráfica obtengo los 10 primeros datos de "datos experimentalos" a 0
% Vamos ajustar la gráfica para que no aparezcan estos ceros

% Buscamos el primer valor distinto de cero
indice_inicio = find(vel_ang(:,1), 1, 'first');

% Ajustar el vector de tiempo y los datos experimentales para comenzar desde cero
tiempo_ajustado = t_sim(indice_inicio:end);
datos_experimentales_ajustados = vel_ang(indice_inicio:end,1);

% Simular el modelo de función de transferencia estimado con el nuevo vector de tiempo
[y_sim_ajustado, t_sim_ajustado] = step(voltaje*anchoPositivo(1)*sys{1}, tiempo_ajustado);

% Comparación entre los datos experimentales ajustados y la simulación del modelo
figure;
plot(tiempo_ajustado, datos_experimentales_ajustados, 'b.-', t_sim_ajustado, y_sim_ajustado, 'r.-');
xlabel('Tiempo (s)');
ylabel('Velocidad Angular (rad/s)');
legend('Datos Experimentales Ajustados', 'Simulación del Modelo');
title('Comparación entre Datos Experimentales Ajustados y Simulación del Modelo para OCR0B = 5');


%% Gráficas de todos los OCR0B
for i=1:16
    % Buscamos el primer valor distinto de cero
    indice_inicio = find(vel_ang(:,i), 1, 'first');
    
    % Ajustar el vector de tiempo y los datos experimentales para comenzar desde cero
    tiempo_ajustado = t_sim(indice_inicio:end);
    datos_experimentales_ajustados = vel_ang(indice_inicio:end,i);

    % Simular el modelo de función de transferencia estimado con el nuevo vector de tiempo
    [y_sim_ajustado, t_sim_ajustado] = step(voltaje*anchoPositivo(i)*sys{i}, tiempo_ajustado);
    
    % Comparación entre los datos experimentales ajustados y la simulación del modelo
    figure;
    plot(tiempo_ajustado, datos_experimentales_ajustados, 'b.-', t_sim_ajustado, y_sim_ajustado, 'r.-');
    xlabel('Tiempo (s)');
    ylabel('Velocidad Angular (rad/s)');
    legend('Datos Experimentales Ajustados', 'Simulación del Modelo');
    title(sprintf('Comparación entre Datos Experimentales Ajustados y Simulación del Modelo para OCR0B = %d', i*5));

    % Ajustar el rango de los ejes x e y para una mejor visualización
    xlim([min(tiempo_ajustado), max(tiempo_ajustado)]);
    ylim([min([datos_experimentales_ajustados; y_sim_ajustado]), max([datos_experimentales_ajustados; y_sim_ajustado])]);
end
