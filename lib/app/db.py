import psycopg2
from psycopg2 import Error
from datetime import datetime, date


def create_database_schema():
    """Crea toda la estructura de la base de datos"""
    connection = get_connection()
    if not connection:
        return False

    try:
        cursor = connection.cursor()

        # 1. Crear tablas de referencia (sin dependencias)
        print("Creando tablas de referencia...")

        # Tabla de tipos de usuario
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS tipos_usuario (
                id_tipo_usuario SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT,
                nivel_acceso INTEGER DEFAULT 0
            );
        """
        )

        # Tabla de estados de usuario
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS estados_usuario (
                id_estado_usuario SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT
            );
        """
        )

        # Tabla de tipos de contenido
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS tipos_contenido (
                id_tipo_contenido SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT,
                extensiones_permitidas JSON
            );
        """
        )

        # Tabla de estados de contenido
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS estados_contenido (
                id_estado_contenido SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT
            );
        """
        )

        # Tabla de tipos de interacción
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS tipos_interaccion (
                id_tipo_interaccion SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT,
                incrementa_contador BOOLEAN DEFAULT true
            );
        """
        )

        # Tabla de tipos de reporte
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS tipos_reporte (
                id_tipo_reporte SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT,
                gravedad INTEGER DEFAULT 1
            );
        """
        )

        # Tabla de estados de reporte
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS estados_reporte (
                id_estado_reporte SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT
            );
        """
        )

        # Tabla de niveles de log
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS niveles_log (
                id_nivel_log SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT
            );
        """
        )

        # Tabla de tipos de notificación
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS tipos_notificacion (
                id_tipo_notificacion SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT,
                plantilla_mensaje TEXT
            );
        """
        )

        # Tabla de estados generales
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS estados_general (
                id_estado_general SERIAL PRIMARY KEY,
                codigo VARCHAR(20) UNIQUE NOT NULL,
                nombre VARCHAR(50) NOT NULL,
                descripcion TEXT,
                tipo_entidad VARCHAR(50) NOT NULL
            );
        """
        )

        # 2. Crear tabla de usuarios (depende de tipos_usuario y estados_usuario)
        print("Creando tabla de usuarios...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS usuarios (
                id_usuario SERIAL PRIMARY KEY,
                id_tipo_usuario INTEGER NOT NULL,
                id_estado_usuario INTEGER NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                fecha_registro TIMESTAMP DEFAULT (NOW()),
                ultimo_login TIMESTAMP,
                token_verificacion VARCHAR(255),
                token_recuperacion VARCHAR(255),
                fecha_expiracion_token TIMESTAMP
            );
        """
        )

        # 3. Crear tablas de perfiles
        print("Creando tablas de perfiles...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS perfiles (
                id_perfil SERIAL PRIMARY KEY,
                id_usuario INTEGER UNIQUE NOT NULL,
                nombre VARCHAR(100) NOT NULL,
                apellido VARCHAR(100) NOT NULL,
                telefono VARCHAR(20),
                avatar_url VARCHAR(500),
                biografia TEXT,
                fecha_actualizacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS estudiantes (
                id_estudiante SERIAL PRIMARY KEY,
                id_usuario INTEGER UNIQUE NOT NULL,
                codigo_estudiante VARCHAR(50) UNIQUE NOT NULL,
                programa_academico VARCHAR(100),
                semestre INTEGER,
                fecha_ingreso DATE
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS docentes (
                id_docente SERIAL PRIMARY KEY,
                id_usuario INTEGER UNIQUE NOT NULL,
                codigo_docente VARCHAR(50) UNIQUE NOT NULL,
                departamento VARCHAR(100),
                titulo_academico VARCHAR(100),
                especialidad VARCHAR(100),
                fecha_contratacion DATE
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS aspirantes (
                id_aspirante SERIAL PRIMARY KEY,
                id_usuario INTEGER UNIQUE NOT NULL,
                documento_identidad VARCHAR(50) UNIQUE NOT NULL,
                fecha_nacimiento DATE,
                ciudad VARCHAR(100),
                pais VARCHAR(100),
                programa_interes VARCHAR(100),
                fecha_solicitud DATE DEFAULT (NOW()),
                acepto_terminos BOOLEAN DEFAULT false,
                fecha_aceptacion_terminos TIMESTAMP
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS administradores (
                id_administrador SERIAL PRIMARY KEY,
                id_usuario INTEGER UNIQUE NOT NULL,
                rol_administrativo VARCHAR(100) NOT NULL,
                nivel_acceso INTEGER DEFAULT 1,
                departamento VARCHAR(100),
                fecha_asignacion DATE DEFAULT (NOW())
            );
        """
        )

        # 4. Crear tablas de preferencias e intereses
        print("Creando tablas de preferencias...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS preferencias_usuario (
                id_preferencia SERIAL PRIMARY KEY,
                id_usuario INTEGER NOT NULL,
                tipo_configuracion VARCHAR(50) NOT NULL,
                clave_configuracion VARCHAR(100) NOT NULL,
                valor_configuracion JSON,
                fecha_creacion TIMESTAMP DEFAULT (NOW()),
                fecha_actualizacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS intereses_usuario (
                id_interes SERIAL PRIMARY KEY,
                id_usuario INTEGER NOT NULL,
                tag_interes VARCHAR(100) NOT NULL,
                peso_interes INTEGER DEFAULT 1,
                fecha_agregado TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        # 5. Crear tablas de categorías y cursos
        print("Creando tablas de categorías y cursos...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS categorias (
                id_categoria SERIAL PRIMARY KEY,
                nombre VARCHAR(100) NOT NULL,
                descripcion TEXT,
                id_categoria_padre INTEGER,
                icono VARCHAR(100),
                color VARCHAR(20),
                id_estado_general INTEGER NOT NULL,
                fecha_creacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS cursos (
                id_curso SERIAL PRIMARY KEY,
                codigo_curso VARCHAR(50) UNIQUE NOT NULL,
                nombre VARCHAR(200) NOT NULL,
                descripcion TEXT,
                id_docente_responsable INTEGER,
                id_estado_general INTEGER NOT NULL,
                es_publico BOOLEAN DEFAULT false,
                fecha_creacion TIMESTAMP DEFAULT (NOW()),
                fecha_actualizacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        # 6. Crear tablas de contenido
        print("Creando tablas de contenido...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS contenidos (
                id_contenido SERIAL PRIMARY KEY,
                titulo VARCHAR(255) NOT NULL,
                descripcion TEXT,
                id_autor INTEGER NOT NULL,
                id_tipo_contenido INTEGER NOT NULL,
                id_estado_contenido INTEGER NOT NULL,
                url_contenido VARCHAR(500) NOT NULL,
                url_thumbnail VARCHAR(500),
                duracion_segundos INTEGER,
                tamanio_bytes BIGINT,
                tiene_subtitulos BOOLEAN DEFAULT false,
                url_subtitulos VARCHAR(500),
                permite_comentarios BOOLEAN DEFAULT true,
                permite_descargas BOOLEAN DEFAULT false,
                visibilidad VARCHAR(20) DEFAULT 'publico',
                fecha_creacion TIMESTAMP DEFAULT (NOW()),
                fecha_publicacion TIMESTAMP,
                fecha_actualizacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS contenido_categorias (
                id_contenido_categoria SERIAL PRIMARY KEY,
                id_contenido INTEGER NOT NULL,
                id_categoria INTEGER NOT NULL,
                fecha_asignacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS contenido_cursos (
                id_contenido_curso SERIAL PRIMARY KEY,
                id_contenido INTEGER NOT NULL,
                id_curso INTEGER NOT NULL,
                orden_en_curso INTEGER DEFAULT 0,
                fecha_asignacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS contenido_palabras_clave (
                id_palabra_clave SERIAL PRIMARY KEY,
                id_contenido INTEGER NOT NULL,
                palabra_clave VARCHAR(100) NOT NULL,
                fecha_agregado TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        # 7. Crear tablas de interacciones
        print("Creando tablas de interacciones...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS interacciones (
                id_interaccion SERIAL PRIMARY KEY,
                id_usuario INTEGER NOT NULL,
                id_contenido INTEGER NOT NULL,
                id_tipo_interaccion INTEGER NOT NULL,
                valor_interaccion INTEGER DEFAULT 1,
                metadata JSON,
                fecha_interaccion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS comentarios (
                id_comentario SERIAL PRIMARY KEY,
                id_usuario INTEGER NOT NULL,
                id_contenido INTEGER NOT NULL,
                id_comentario_padre INTEGER,
                texto TEXT NOT NULL,
                id_estado_general INTEGER NOT NULL,
                fecha_creacion TIMESTAMP DEFAULT (NOW()),
                fecha_actualizacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        # 8. Crear tablas de reportes
        print("Creando tablas de reportes...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS reportes (
                id_reporte SERIAL PRIMARY KEY,
                id_usuario_reportero INTEGER NOT NULL,
                id_contenido INTEGER,
                id_comentario INTEGER,
                id_tipo_reporte INTEGER NOT NULL,
                id_estado_reporte INTEGER NOT NULL,
                descripcion TEXT NOT NULL,
                fecha_reporte TIMESTAMP DEFAULT (NOW()),
                fecha_resolucion TIMESTAMP,
                id_administrador_resuelve INTEGER,
                accion_tomada TEXT
            );
        """
        )

        # 9. Crear tablas de seguimiento y favoritos
        print("Creando tablas de seguimiento...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS seguimientos (
                id_seguimiento SERIAL PRIMARY KEY,
                id_usuario_seguidor INTEGER NOT NULL,
                id_usuario_seguido INTEGER NOT NULL,
                notificaciones_activas BOOLEAN DEFAULT true,
                fecha_seguimiento TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS favoritos (
                id_favorito SERIAL PRIMARY KEY,
                id_usuario INTEGER NOT NULL,
                id_contenido INTEGER NOT NULL,
                fecha_agregado TIMESTAMP DEFAULT (NOW()),
                carpeta VARCHAR(100) DEFAULT 'general'
            );
        """
        )

        # 10. Crear tablas de historial
        print("Creando tablas de historial...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS historial_busquedas (
                id_busqueda SERIAL PRIMARY KEY,
                id_usuario INTEGER,
                termino_busqueda VARCHAR(255) NOT NULL,
                resultados_encontrados INTEGER DEFAULT 0,
                filtros_aplicados JSON,
                fecha_busqueda TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS historial_vistas (
                id_vista SERIAL PRIMARY KEY,
                id_usuario INTEGER NOT NULL,
                id_contenido INTEGER NOT NULL,
                tiempo_reproduccion_segundos INTEGER DEFAULT 0,
                porcentaje_visto INTEGER DEFAULT 0,
                fecha_vista TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        # 11. Crear tablas de roles y configuración
        print("Creando tablas de roles...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS roles_sistema (
                id_rol SERIAL PRIMARY KEY,
                codigo_rol VARCHAR(50) UNIQUE NOT NULL,
                nombre_rol VARCHAR(100) NOT NULL,
                descripcion TEXT,
                permisos JSON NOT NULL,
                fecha_creacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS usuario_roles (
                id_usuario_rol SERIAL PRIMARY KEY,
                id_usuario INTEGER NOT NULL,
                id_rol INTEGER NOT NULL,
                fecha_asignacion TIMESTAMP DEFAULT (NOW()),
                id_administrador_asigna INTEGER
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS configuracion_sistema (
                id_configuracion SERIAL PRIMARY KEY,
                clave VARCHAR(100) UNIQUE NOT NULL,
                valor JSON NOT NULL,
                tipo_dato VARCHAR(50) NOT NULL,
                descripcion TEXT,
                es_editable BOOLEAN DEFAULT true,
                categoria VARCHAR(50) DEFAULT 'general',
                fecha_creacion TIMESTAMP DEFAULT (NOW()),
                fecha_actualizacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        # 12. Crear tablas de logs y notificaciones
        print("Creando tablas de logs...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS logs_sistema (
                id_log SERIAL PRIMARY KEY,
                id_nivel_log INTEGER NOT NULL,
                modulo VARCHAR(100) NOT NULL,
                mensaje TEXT NOT NULL,
                metadata JSON,
                id_usuario INTEGER,
                ip_address VARCHAR(45),
                user_agent TEXT,
                fecha_log TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS notificaciones (
                id_notificacion SERIAL PRIMARY KEY,
                id_usuario_destino INTEGER NOT NULL,
                id_tipo_notificacion INTEGER NOT NULL,
                titulo VARCHAR(255) NOT NULL,
                mensaje TEXT NOT NULL,
                enlace_accion VARCHAR(500),
                leida BOOLEAN DEFAULT false,
                fecha_creacion TIMESTAMP DEFAULT (NOW()),
                fecha_lectura TIMESTAMP
            );
        """
        )

        # 13. Crear tablas de sesiones y FAQ
        print("Creando tablas de sesiones y FAQ...")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS sesiones_activas (
                id_sesion SERIAL PRIMARY KEY,
                id_usuario INTEGER NOT NULL,
                token_sesion VARCHAR(500) UNIQUE NOT NULL,
                dispositivo VARCHAR(255),
                sistema_operativo VARCHAR(100),
                navegador VARCHAR(100),
                ip_address VARCHAR(45),
                fecha_inicio TIMESTAMP DEFAULT (NOW()),
                fecha_ultima_actividad TIMESTAMP DEFAULT (NOW()),
                fecha_expiracion TIMESTAMP NOT NULL,
                id_estado_general INTEGER NOT NULL
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS faq_categorias (
                id_faq_categoria SERIAL PRIMARY KEY,
                nombre VARCHAR(100) NOT NULL,
                descripcion TEXT,
                orden INTEGER DEFAULT 0,
                id_estado_general INTEGER NOT NULL
            );
        """
        )

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS preguntas_frecuentes (
                id_faq SERIAL PRIMARY KEY,
                id_faq_categoria INTEGER NOT NULL,
                pregunta TEXT NOT NULL,
                respuesta TEXT NOT NULL,
                orden INTEGER DEFAULT 0,
                id_estado_general INTEGER NOT NULL,
                fecha_creacion TIMESTAMP DEFAULT (NOW()),
                fecha_actualizacion TIMESTAMP DEFAULT (NOW())
            );
        """
        )

        # 14. Agregar constraints de foreign keys
        print("Agregando constraints de foreign keys...")

        # Foreign keys para usuarios
        cursor.execute(
            """
            ALTER TABLE usuarios 
            ADD CONSTRAINT fk_usuarios_tipos_usuario 
            FOREIGN KEY (id_tipo_usuario) REFERENCES tipos_usuario(id_tipo_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE usuarios 
            ADD CONSTRAINT fk_usuarios_estados_usuario 
            FOREIGN KEY (id_estado_usuario) REFERENCES estados_usuario(id_estado_usuario);
        """
        )

        # Foreign keys para perfiles
        cursor.execute(
            """
            ALTER TABLE perfiles 
            ADD CONSTRAINT fk_perfiles_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE estudiantes 
            ADD CONSTRAINT fk_estudiantes_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE docentes 
            ADD CONSTRAINT fk_docentes_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE aspirantes 
            ADD CONSTRAINT fk_aspirantes_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE administradores 
            ADD CONSTRAINT fk_administradores_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        # Foreign keys para categorías
        cursor.execute(
            """
            ALTER TABLE categorias 
            ADD CONSTRAINT fk_categorias_categorias_padre 
            FOREIGN KEY (id_categoria_padre) REFERENCES categorias(id_categoria);
        """
        )

        cursor.execute(
            """
            ALTER TABLE categorias 
            ADD CONSTRAINT fk_categorias_estados_general 
            FOREIGN KEY (id_estado_general) REFERENCES estados_general(id_estado_general);
        """
        )

        # Foreign keys para cursos
        cursor.execute(
            """
            ALTER TABLE cursos 
            ADD CONSTRAINT fk_cursos_docentes 
            FOREIGN KEY (id_docente_responsable) REFERENCES docentes(id_docente);
        """
        )

        cursor.execute(
            """
            ALTER TABLE cursos 
            ADD CONSTRAINT fk_cursos_estados_general 
            FOREIGN KEY (id_estado_general) REFERENCES estados_general(id_estado_general);
        """
        )

        # Foreign keys para contenidos
        cursor.execute(
            """
            ALTER TABLE contenidos 
            ADD CONSTRAINT fk_contenidos_usuarios 
            FOREIGN KEY (id_autor) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE contenidos 
            ADD CONSTRAINT fk_contenidos_tipos_contenido 
            FOREIGN KEY (id_tipo_contenido) REFERENCES tipos_contenido(id_tipo_contenido);
        """
        )

        cursor.execute(
            """
            ALTER TABLE contenidos 
            ADD CONSTRAINT fk_contenidos_estados_contenido 
            FOREIGN KEY (id_estado_contenido) REFERENCES estados_contenido(id_estado_contenido);
        """
        )

        # Foreign keys para relaciones de contenido
        cursor.execute(
            """
            ALTER TABLE contenido_categorias 
            ADD CONSTRAINT fk_contenido_categorias_contenidos 
            FOREIGN KEY (id_contenido) REFERENCES contenidos(id_contenido);
        """
        )

        cursor.execute(
            """
            ALTER TABLE contenido_categorias 
            ADD CONSTRAINT fk_contenido_categorias_categorias 
            FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria);
        """
        )

        cursor.execute(
            """
            ALTER TABLE contenido_cursos 
            ADD CONSTRAINT fk_contenido_cursos_contenidos 
            FOREIGN KEY (id_contenido) REFERENCES contenidos(id_contenido);
        """
        )

        cursor.execute(
            """
            ALTER TABLE contenido_cursos 
            ADD CONSTRAINT fk_contenido_cursos_cursos 
            FOREIGN KEY (id_curso) REFERENCES cursos(id_curso);
        """
        )

        cursor.execute(
            """
            ALTER TABLE contenido_palabras_clave 
            ADD CONSTRAINT fk_contenido_palabras_clave_contenidos 
            FOREIGN KEY (id_contenido) REFERENCES contenidos(id_contenido);
        """
        )

        # Foreign keys para interacciones
        cursor.execute(
            """
            ALTER TABLE interacciones 
            ADD CONSTRAINT fk_interacciones_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE interacciones 
            ADD CONSTRAINT fk_interacciones_contenidos 
            FOREIGN KEY (id_contenido) REFERENCES contenidos(id_contenido);
        """
        )

        cursor.execute(
            """
            ALTER TABLE interacciones 
            ADD CONSTRAINT fk_interacciones_tipos_interaccion 
            FOREIGN KEY (id_tipo_interaccion) REFERENCES tipos_interaccion(id_tipo_interaccion);
        """
        )

        # Foreign keys para comentarios
        cursor.execute(
            """
            ALTER TABLE comentarios 
            ADD CONSTRAINT fk_comentarios_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE comentarios 
            ADD CONSTRAINT fk_comentarios_contenidos 
            FOREIGN KEY (id_contenido) REFERENCES contenidos(id_contenido);
        """
        )

        cursor.execute(
            """
            ALTER TABLE comentarios 
            ADD CONSTRAINT fk_comentarios_comentarios_padre 
            FOREIGN KEY (id_comentario_padre) REFERENCES comentarios(id_comentario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE comentarios 
            ADD CONSTRAINT fk_comentarios_estados_general 
            FOREIGN KEY (id_estado_general) REFERENCES estados_general(id_estado_general);
        """
        )

        # Foreign keys para reportes
        cursor.execute(
            """
            ALTER TABLE reportes 
            ADD CONSTRAINT fk_reportes_usuarios_reportero 
            FOREIGN KEY (id_usuario_reportero) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE reportes 
            ADD CONSTRAINT fk_reportes_contenidos 
            FOREIGN KEY (id_contenido) REFERENCES contenidos(id_contenido);
        """
        )

        cursor.execute(
            """
            ALTER TABLE reportes 
            ADD CONSTRAINT fk_reportes_comentarios 
            FOREIGN KEY (id_comentario) REFERENCES comentarios(id_comentario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE reportes 
            ADD CONSTRAINT fk_reportes_tipos_reporte 
            FOREIGN KEY (id_tipo_reporte) REFERENCES tipos_reporte(id_tipo_reporte);
        """
        )

        cursor.execute(
            """
            ALTER TABLE reportes 
            ADD CONSTRAINT fk_reportes_estados_reporte 
            FOREIGN KEY (id_estado_reporte) REFERENCES estados_reporte(id_estado_reporte);
        """
        )

        cursor.execute(
            """
            ALTER TABLE reportes 
            ADD CONSTRAINT fk_reportes_administradores 
            FOREIGN KEY (id_administrador_resuelve) REFERENCES administradores(id_administrador);
        """
        )

        # Foreign keys para seguimientos y favoritos
        cursor.execute(
            """
            ALTER TABLE seguimientos 
            ADD CONSTRAINT fk_seguimientos_usuarios_seguidor 
            FOREIGN KEY (id_usuario_seguidor) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE seguimientos 
            ADD CONSTRAINT fk_seguimientos_usuarios_seguido 
            FOREIGN KEY (id_usuario_seguido) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE favoritos 
            ADD CONSTRAINT fk_favoritos_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE favoritos 
            ADD CONSTRAINT fk_favoritos_contenidos 
            FOREIGN KEY (id_contenido) REFERENCES contenidos(id_contenido);
        """
        )

        # Foreign keys para historial
        cursor.execute(
            """
            ALTER TABLE historial_busquedas 
            ADD CONSTRAINT fk_historial_busquedas_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE historial_vistas 
            ADD CONSTRAINT fk_historial_vistas_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE historial_vistas 
            ADD CONSTRAINT fk_historial_vistas_contenidos 
            FOREIGN KEY (id_contenido) REFERENCES contenidos(id_contenido);
        """
        )

        # Foreign keys para roles
        cursor.execute(
            """
            ALTER TABLE usuario_roles 
            ADD CONSTRAINT fk_usuario_roles_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE usuario_roles 
            ADD CONSTRAINT fk_usuario_roles_roles 
            FOREIGN KEY (id_rol) REFERENCES roles_sistema(id_rol);
        """
        )

        cursor.execute(
            """
            ALTER TABLE usuario_roles 
            ADD CONSTRAINT fk_usuario_roles_administradores 
            FOREIGN KEY (id_administrador_asigna) REFERENCES administradores(id_administrador);
        """
        )

        # Foreign keys para logs
        cursor.execute(
            """
            ALTER TABLE logs_sistema 
            ADD CONSTRAINT fk_logs_sistema_niveles_log 
            FOREIGN KEY (id_nivel_log) REFERENCES niveles_log(id_nivel_log);
        """
        )

        cursor.execute(
            """
            ALTER TABLE logs_sistema 
            ADD CONSTRAINT fk_logs_sistema_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        # Foreign keys para notificaciones
        cursor.execute(
            """
            ALTER TABLE notificaciones 
            ADD CONSTRAINT fk_notificaciones_usuarios 
            FOREIGN KEY (id_usuario_destino) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE notificaciones 
            ADD CONSTRAINT fk_notificaciones_tipos_notificacion 
            FOREIGN KEY (id_tipo_notificacion) REFERENCES tipos_notificacion(id_tipo_notificacion);
        """
        )

        # Foreign keys para sesiones
        cursor.execute(
            """
            ALTER TABLE sesiones_activas 
            ADD CONSTRAINT fk_sesiones_activas_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE sesiones_activas 
            ADD CONSTRAINT fk_sesiones_activas_estados_general 
            FOREIGN KEY (id_estado_general) REFERENCES estados_general(id_estado_general);
        """
        )

        # Foreign keys para FAQ
        cursor.execute(
            """
            ALTER TABLE preguntas_frecuentes 
            ADD CONSTRAINT fk_preguntas_frecuentes_faq_categorias 
            FOREIGN KEY (id_faq_categoria) REFERENCES faq_categorias(id_faq_categoria);
        """
        )

        cursor.execute(
            """
            ALTER TABLE preguntas_frecuentes 
            ADD CONSTRAINT fk_preguntas_frecuentes_estados_general 
            FOREIGN KEY (id_estado_general) REFERENCES estados_general(id_estado_general);
        """
        )

        cursor.execute(
            """
            ALTER TABLE faq_categorias 
            ADD CONSTRAINT fk_faq_categorias_estados_general 
            FOREIGN KEY (id_estado_general) REFERENCES estados_general(id_estado_general);
        """
        )

        # Foreign keys para preferencias e intereses
        cursor.execute(
            """
            ALTER TABLE preferencias_usuario 
            ADD CONSTRAINT fk_preferencias_usuario_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        cursor.execute(
            """
            ALTER TABLE intereses_usuario 
            ADD CONSTRAINT fk_intereses_usuario_usuarios 
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);
        """
        )

        connection.commit()
        print("✅ Esquema de base de datos creado exitosamente!")
        return True

    except (Exception, Error) as error:
        print("❌ Error al crear el esquema:", error)
        connection.rollback()
        return False
    finally:
        if connection:
            cursor.close()
            connection.close()


def insert_initial_data():
    """Inserta datos iniciales en las tablas de referencia"""
    connection = get_connection()
    if not connection:
        return False

    try:
        cursor = connection.cursor()

        print("Insertando datos iniciales...")

        # Insertar tipos de usuario
        cursor.execute(
            """
            INSERT INTO tipos_usuario (codigo, nombre, descripcion, nivel_acceso) 
            VALUES 
            ('admin', 'Administrador', 'Usuario con permisos de administración', 10),
            ('docente', 'Docente', 'Profesor o instructor', 5),
            ('estudiante', 'Estudiante', 'Estudiante regular', 3),
            ('aspirante', 'Aspirante', 'Postulante a programas', 1)
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar estados de usuario
        cursor.execute(
            """
            INSERT INTO estados_usuario (codigo, nombre, descripcion) 
            VALUES 
            ('activo', 'Activo', 'Usuario activo en el sistema'),
            ('inactivo', 'Inactivo', 'Usuario inactivo temporalmente'),
            ('bloqueado', 'Bloqueado', 'Usuario bloqueado por infracciones'),
            ('pendiente', 'Pendiente', 'Esperando verificación de email')
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar tipos de contenido
        cursor.execute(
            """
            INSERT INTO tipos_contenido (codigo, nombre, descripcion, extensiones_permitidas) 
            VALUES 
            ('video', 'Video', 'Contenido multimedia de video', '["mp4", "avi", "mov", "mkv"]'),
            ('audio', 'Audio', 'Contenido multimedia de audio', '["mp3", "wav", "ogg", "m4a"]'),
            ('documento', 'Documento', 'Documentos digitales', '["pdf", "doc", "docx", "ppt", "pptx"]'),
            ('imagen', 'Imagen', 'Contenido visual', '["jpg", "jpeg", "png", "gif", "bmp"]'),
            ('enlace', 'Enlace', 'Enlace externo', '[]')
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar estados de contenido
        cursor.execute(
            """
            INSERT INTO estados_contenido (codigo, nombre, descripcion) 
            VALUES 
            ('borrador', 'Borrador', 'Contenido en edición'),
            ('revision', 'En revisión', 'Esperando aprobación'),
            ('publicado', 'Publicado', 'Contenido disponible'),
            ('archivado', 'Archivado', 'Contenido archivado'),
            ('rechazado', 'Rechazado', 'Contenido rechazado')
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar tipos de interacción
        cursor.execute(
            """
            INSERT INTO tipos_interaccion (codigo, nombre, descripcion, incrementa_contador) 
            VALUES 
            ('like', 'Like', 'Me gusta', true),
            ('dislike', 'Dislike', 'No me gusta', true),
            ('vista', 'Vista', 'Visualización del contenido', true),
            ('compartir', 'Compartir', 'Compartir contenido', true),
            ('comentario', 'Comentario', 'Comentar contenido', false)
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar tipos de reporte
        cursor.execute(
            """
            INSERT INTO tipos_reporte (codigo, nombre, descripcion, gravedad) 
            VALUES 
            ('spam', 'Spam', 'Contenido no deseado', 1),
            ('inapropiado', 'Inapropiado', 'Contenido inapropiado', 3),
            ('derechos', 'Derechos de autor', 'Violación de derechos de autor', 4),
            ('acoso', 'Acoso', 'Contenido acosador', 5),
            ('otro', 'Otro', 'Otro tipo de reporte', 2)
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar estados de reporte
        cursor.execute(
            """
            INSERT INTO estados_reporte (codigo, nombre, descripcion) 
            VALUES 
            ('pendiente', 'Pendiente', 'Reporte pendiente de revisión'),
            ('revisado', 'Revisado', 'Reporte en proceso de revisión'),
            ('resuelto', 'Resuelto', 'Reporte resuelto'),
            ('desestimado', 'Desestimado', 'Reporte desestimado')
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar niveles de log
        cursor.execute(
            """
            INSERT INTO niveles_log (codigo, nombre, descripcion) 
            VALUES 
            ('debug', 'Debug', 'Mensajes de depuración'),
            ('info', 'Información', 'Mensajes informativos'),
            ('warning', 'Advertencia', 'Mensajes de advertencia'),
            ('error', 'Error', 'Mensajes de error'),
            ('critical', 'Crítico', 'Mensajes críticos')
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar tipos de notificación
        cursor.execute(
            """
            INSERT INTO tipos_notificacion (codigo, nombre, descripcion, plantilla_mensaje) 
            VALUES 
            ('sistema', 'Sistema', 'Notificación del sistema', 'Notificación del sistema: {mensaje}'),
            ('seguimiento', 'Seguimiento', 'Notificación de seguimiento', '{usuario} empezó a seguirte'),
            ('comentario', 'Comentario', 'Notificación de comentario', '{usuario} comentó en tu contenido'),
            ('like', 'Like', 'Notificación de like', 'A {usuario} le gusta tu contenido'),
            ('reporte', 'Reporte', 'Notificación de reporte', 'Tu reporte ha sido {estado}')
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar estados generales
        cursor.execute(
            """
            INSERT INTO estados_general (codigo, nombre, descripcion, tipo_entidad) 
            VALUES 
            ('activo', 'Activo', 'Registro activo', 'general'),
            ('inactivo', 'Inactivo', 'Registro inactivo', 'general'),
            ('pendiente', 'Pendiente', 'Esperando aprobación', 'general'),
            ('eliminado', 'Eliminado', 'Registro eliminado', 'general')
            ON CONFLICT (codigo) DO NOTHING;
        """
        )

        # Insertar roles del sistema
        cursor.execute(
            """
            INSERT INTO roles_sistema (codigo_rol, nombre_rol, descripcion, permisos) 
            VALUES 
            ('superadmin', 'Super Administrador', 'Acceso total al sistema', '["*"]'),
            ('admin', 'Administrador', 'Administrador del sistema', '["users.manage", "content.manage", "reports.manage"]'),
            ('moderador', 'Moderador', 'Moderador de contenido', '["content.moderate", "reports.review"]'),
            ('docente', 'Docente', 'Rol para profesores', '["content.create", "content.edit", "courses.manage"]'),
            ('estudiante', 'Estudiante', 'Rol para estudiantes', '["content.view", "courses.enroll"]')
            ON CONFLICT (codigo_rol) DO NOTHING;
        """
        )

        connection.commit()
        print("✅ Datos iniciales insertados correctamente")
        return True

    except (Exception, Error) as error:
        print("❌ Error al insertar datos iniciales:", error)
        connection.rollback()
        return False
    finally:
        if connection:
            cursor.close()
            connection.close()


def get_connection():
    """Establece y retorna la conexión a la base de datos"""
    try:
        connection = psycopg2.connect(
            dbname="railway",
            user="postgres",
            password="MYhcoFuYMGEFrSqgwFIcRWDDPJZswQhi",
            host="yamabiko.proxy.rlwy.net",
            port="29558",
            sslmode="require",
        )
        return connection
    except (Exception, Error) as error:
        print(" Error al conectar a PostgreSQL", error)
        return None


def main():
    """Función principal que ejecuta la creación completa"""
    print("🚀 Iniciando creación de la base de datos...")

    # Crear el esquema
    if create_database_schema():
        # Insertar datos iniciales
        if insert_initial_data():
            print("🎉 ¡Base de datos creada exitosamente!")
            print("📊 Estructura completa lista para usar")
        else:
            print("⚠️  Esquema creado pero hubo errores en datos iniciales")
    else:
        print("💥 Error al crear el esquema de la base de datos")


if __name__ == "__main__":
    main()

# /home/lincj/Vídeos
