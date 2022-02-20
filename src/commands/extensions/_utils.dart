import 'package:extensions/metadata.dart';
import 'package:utilx/utilities/utils.dart';
import '../../core/extensions.dart';
import '../../utils/console.dart';

String dyeStoreMetadata(final EMetadata metadata) =>
    '${Dye.dye(metadata.name, ExtensionsManager.repository.isInstalled(metadata) ? 'lightGreen' : 'cyan')} ${Dye.dye('[${StringUtils.capitalize(metadata.type.name)}/${metadata.author}/v${metadata.version}]', 'darkGray')}';