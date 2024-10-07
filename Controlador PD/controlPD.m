% Los datos en el fichero ControlPD estan almacenados de la manera 
% ADC, Error y Error derivada. Se envia la Referencia y Kp una unica vez.

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
fichero = fopen('ControlPD.txt', 'w');

%Numero de datos que quiero leer
num_lecturas = 3000;

while num_lecturas > 0
    linea = readline(serial);
    resul = sscanf(linea, '%d');
    %Guardar los pulsos en el archivo correspondiente
    fprintf(fichero, '%d %d %d\n', resul);
    %Reducir el contador de lecturas
    num_lecturas = num_lecturas - 1; 
end

% Cerrar el archivo y el puerto serie
fclose(fichero);
clear serial;

%% Plotear datos

load("ControlPD.txt");

%Kp = 50;  % Si queremos usar un fichero que ya tiene datos, es decir no 
           % hacer el proceso de leer desde el Arduino, debemos
           % indicar el valor de Kp que estamos usando (Kd no es neceserio,
           % el error derivativo ya se envía multiplicado)

adc = ControlPD(:,1);
error = ControlPD(:,2);
errorD = ControlPD(:,3);    %Ya está multiplicado por Kd

n_muestras = length(adc);

adc_voltaje = zeros(n_muestras,1);
U = zeros (n_muestras,1);

for i=1:length(adc)
    adc_voltaje(i) = (adc(i)*1.1) / 1023;
end

%Construimos la señal de control
for i=1:length(error)
    U(i) = fix(Kp*error(i) + errorD(i));
end

% Crear un vector de tiempo para el eje x
tiempo = (1:n_muestras) * 0.01; %Multiplicar por tiempo de muestreo de 0.01s 

% Crear figuras para cada señal
figure;
subplot(2, 2, 1);
plot(tiempo, adc, '.-');
title('Datos del ADC', 'FontSize', 20);
xlabel('Tiempo (s)', 'FontSize', 18);
ylabel('Valor ADC (Digital)', 'FontSize', 18);
grid on;
for k = 2:2:30
    xline(k, 'r', 'LineWidth', 2);
end

subplot(2, 2, 2);
plot(tiempo, error, '.-');
title('Señal de Error (E)', 'FontSize', 20);
xlabel('Tiempo (s)');
ylabel('Valor Error (E)');
grid on;
for k = 2:2:30
    xline(k, 'r', 'LineWidth', 2);
end

subplot(2, 2, 3);
plot(tiempo, errorD, '.-');
title('Señal de Error Derivativo (Ed)', 'FontSize', 20);
xlabel('Tiempo (s)', 'FontSize', 18);
ylabel('Valor Error Derivativo(Ed)', 'FontSize', 18);
grid on;
for k = 2:2:30
    xline(k, 'r', 'LineWidth', 2);
end


subplot(2, 2, 4);
plot(tiempo, U, '.-');
title('Señal de Control (U)', 'FontSize', 20);
xlabel('Tiempo (s)', 'FontSize', 18);
ylabel('Valor Control (U)', 'FontSize', 18);
grid on;
for k = 2:2:30
    xline(k, 'r', 'LineWidth', 2);
end




