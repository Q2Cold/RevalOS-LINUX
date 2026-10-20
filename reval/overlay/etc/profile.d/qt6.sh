export QT6DIR=/opt/qt6

case ":$PATH:" in
    *":$QT6DIR/bin:"*) ;;
    *) export PATH="$QT6DIR/bin:$PATH" ;;
esac

case ":${PKG_CONFIG_PATH:-}:" in
    *":$QT6DIR/lib/pkgconfig:"*) ;;
    *) export PKG_CONFIG_PATH="$QT6DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" ;;
esac

case ":${CMAKE_PREFIX_PATH:-}:" in
    *":$QT6DIR:"*) ;;
    *) export CMAKE_PREFIX_PATH="$QT6DIR${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}" ;;
esac
