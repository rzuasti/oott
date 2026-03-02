//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <encrypter/encrypter_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) encrypter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "EncrypterPlugin");
  encrypter_plugin_register_with_registrar(encrypter_registrar);
}
