//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <file_selector_linux/file_selector_plugin.h>
#include <zstandard_linux/zstandard_linux_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) file_selector_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FileSelectorPlugin");
  file_selector_plugin_register_with_registrar(file_selector_linux_registrar);
  g_autoptr(FlPluginRegistrar) zstandard_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "ZstandardLinuxPlugin");
  zstandard_linux_plugin_register_with_registrar(zstandard_linux_registrar);
}
