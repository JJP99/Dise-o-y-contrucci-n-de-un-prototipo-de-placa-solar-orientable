%Configuración del puerto serie
serial = serialport("COM5", 38400);

%Establecer el tiempo de espera (timeout) del puerto serie
serial.Timeout = 60;

%Contadores para las lecturas del Encoder
num_lecturas = 5; %1

% Abrir el fichero para almacenar los datos del Encoder

fichero = fopen('Encoder_C.txt', 'w');    %Almacenamos los pulsos/seg

%Los ficheros con nombre Encoder_C... son con carga y Encoder_S sin carga

while num_lecturas > 0
    %Leer los datos del puerto serie
    dato = read(serial, 8*40, "string");
    pulsos_seg = sscanf(dato, '%d');
    %Guardar los pulsos en el archivo correspondiente
    fprintf(fichero, '%d %d\n', pulsos_seg);
    %Reducir el contador de lecturas
    num_lecturas = num_lecturas - 1; 
end 

% Cerrar el archivo y el puerto serie
fclose(fichero);
clear serial;