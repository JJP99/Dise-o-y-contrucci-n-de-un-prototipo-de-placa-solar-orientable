% Los datos en el fichero ControlP estan almacenados de la manera 
% ADC y Error. Se envia la Referencia y Kp una unica vez.

clear;
close all;

%% Guardar datos en un fichero

% Configuración del puerto serie
serial = serialport("COM5", 38400);

%Establecer el tiempo de espera (timeout) del puerto serie
%serial.Timeout = 150;

% Leer la referencia y Kp una vez
linea = readline(serial);
referencia = sscanf(linea, '%d');

linea = readline(serial);
Kp = sscanf(linea, '%f');

%Abrir el fichero para almacenar los datos
fichero = fopen('ControlP.txt', 'w');

%Numero de datos que quiero leer
num_lecturas = 3000;

while num_lecturas > 0
    linea = readline(serial);
    resul = sscanf(linea, '%d');
    %Guardar los pulsos en el archivo correspondiente
    fprintf(fichero, '%d %d\n', resul);
    %Reducir el contador de lecturas
    num_lecturas = num_lecturas - 1; 
end

% Cerrar el archivo y el puerto serie
fclose(fichero);
clear serial;

%% Plotear Datos

load("ControlP.txt");

%Kp = 0.5; % Si queremos usar un fichero que ya tiene datos, es decir no 
           % hacer el proceso de leer desde el Arduino, debemos
           % indicar el valor de Kp que estamos usando 

adc = ControlP(:,1);
error = ControlP(:,2);

n_muestras = length(adc);

adc_voltaje = zeros(n_muestras,1);
U = zeros (n_muestras,1);

for i=1:length(adc)
    adc_voltaje(i) = (adc(i)*1.1) / 1023;
end

%Construimos la señal de control
for i=1:length(error)
    U(i) = fix(Kp*error(i));
end

% Crear un vector de tiempo para el eje x
tiempo = (1:n_muestras) * 0.01 ; 

% Crear figuras para cada señal
figure;
subplot(3, 1, 1);
plot(tiempo, adc, '.-');
title('Datos del ADC', 'FontSize', 20);
xlabel('Tiempo (s)', 'FontSize', 18);
ylabel('Valor ADC (Digital)', 'FontSize', 18);
grid on;
for k = 2.5:2.5:30
    xline(k, 'r', 'LineWidth', 2);
end

subplot(3, 1, 2);
plot(tiempo, error, '.-');
title('Señal de Error (E)', 'FontSize', 20);
xlabel('Tiempo (s)', 'FontSize', 18);
ylabel('Valor Error (E)', 'FontSize', 18);
grid on;
for k = 2.5:2.5:30
    xline(k, 'r', 'LineWidth', 2);
end

subplot(3, 1, 3);
plot(tiempo, U, '.-');
title('Señal de Control (U)', 'FontSize', 20);
xlabel('Tiempo (s)', 'FontSize', 18);
ylabel('Valor Control (U)', 'FontSize', 18);
grid on;
for k = 2.5:2.5:30
    xline(k, 'r', 'LineWidth', 2);
end

