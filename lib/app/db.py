import psycopg2
from psycopg2 import Error

# postgresql://postgres:MYhcoFuYMGEFrSqgwFIcRWDDPJZswQhi@yamabiko.proxy.rlwy.net:29558/railway
try:
    # Establecer la conexión
    connection = psycopg2.connect(
        dbname="railway",  # Nombre de la base de datos
        user="postgres",  # Usuario
        password="MYhcoFuYMGEFrSqgwFIcRWDDPJZswQhi",  # Contraseña
        host="yamabiko.proxy.rlwy.net",  # Dominio proxy para conexiones externas
        port="29558",  # Puerto del proxy
        sslmode="require",  # Modo SSL
    )

    # Crear un cursor
    cursor = connection.cursor()

    # Confirmar los cambios
    connection.commit()

except (Exception, Error) as error:
    print("Error al conectar a PostgreSQL", error)
finally:
    if connection:
        cursor.close()
        connection.close()
        print("Conexión a PostgreSQL cerrada")
