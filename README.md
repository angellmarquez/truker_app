# TruckFleet

Sistema de seguimiento en tiempo real para empresa de camiones, desarrollado en Flutter y Firebase.

## Requisitos previos

- Tener instalado [Flutter](https://docs.flutter.dev/get-started/install) (SDK 3.0.0 o superior)
- Tener instalado [Git](https://git-scm.com/)
- Tener una cuenta de Firebase y configurar el proyecto (ya incluido en este repo)

## Instalación y primer inicio

1. **Clona el repositorio:**
	 ```bash
	 git clone https://github.com/angellmarquez/truker_app.git
	 cd truker_app
	 ```

2. **Instala las dependencias:**
	 ```bash
	 flutter pub get
	 ```

3. **Configura Firebase:**
	 - Los archivos de configuración (`google-services.json` y `firebase_options.dart`) ya están incluidos.
	 - Si necesitas regenerarlos, usa el [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/).

4. **Ejecuta la app:**
	 - **Android:**
		 ```bash
		 flutter run -d android
		 ```
	 - **iOS:**
		 ```bash
		 flutter run -d ios
		 ```
	 - **Web:**
		 ```bash
		 flutter run -d chrome
		 ```
	 - **Windows/Linux/Mac:**
		 ```bash
		 flutter run -d windows # o linux, macos
		 ```

## Estructura principal del proyecto

- `lib/` Código fuente principal (pantallas, modelos, servicios, temas)
- `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/` Archivos de plataforma
- `pubspec.yaml` Dependencias y configuración de Flutter

## Notas

- Asegúrate de tener un emulador o dispositivo físico conectado.
- Si usas funcionalidades de mapas, notificaciones o cámara, otorga los permisos necesarios en cada plataforma.
- Para producción, revisa la configuración de seguridad de Firebase.

---
¿Dudas? Abre un issue o contacta al autor.
