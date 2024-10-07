% Configuración del puerto serie
serial = serialport("COM5", 38400);

%Establecer el tiempo de espera (timeout) del puerto serie
serial.Timeout = 150;

%Contadores para las lecturas de voltaje
num_lecturas = 4; %4*250 = 1000 Medidas

%Abrir el fichero para almacenar los datos de voltaje
%Modificar nombre del txt para cada medida
ficheroA0 = fopen('Voltaje_90.txt', 'w');    %Voltaje con R=500hmios

while num_lecturas > 0
    %Leer los datos del puerto serie
    dato = read(serial, 11*250, "string");   %11 es el numero de caracteres del string, 8 del numero, 1 del '\r', 1 del '\n' y 1 del '\0' 
    voltajeA0 = sscanf(dato, '%f');
    %Guardar el voltaje en el archivo correspondiente
    fprintf(ficheroA0, '%f\n', voltajeA0);
    %Reducir el contador de lecturas
    num_lecturas = num_lecturas - 1; 
end 

%Cerrar el archivo y el puerto serie
fclose(ficheroA0);
clear serial;
