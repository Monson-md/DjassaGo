// Test de la Phase 5 : le PIN n'est jamais stocké en clair, seul un hash
// salé l'est. On utilise un faux stockage en mémoire (voir
// _FakeStockageSecurise) pour tester la logique de hachage/vérification
// sans dépendre du canal natif de flutter_secure_storage.

import 'package:caisse_de_poche/services/pin_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStockageSecurise implements StockageSecurise {
  final Map<String, String> _valeurs = {};

  @override
  Future<String?> lire(String cle) async => _valeurs[cle];

  @override
  Future<void> ecrire(String cle, String valeur) async {
    _valeurs[cle] = valeur;
  }

  @override
  Future<void> supprimer(String cle) async {
    _valeurs.remove(cle);
  }
}

void main() {
  test(
      'PinService hache le PIN (jamais en clair), vérifie correctement, et '
      'permet une réinitialisation via la question secrète', () async {
    final stockage = _FakeStockageSecurise();
    final service = PinService(stockage: stockage);

    expect(await service.pinConfigure(), isFalse);

    await service.definirPin(
      '4821',
      question: 'Nom de mon premier client ?',
      reponse: 'Aya',
    );

    expect(await service.pinConfigure(), isTrue);
    // Le PIN en clair n'apparaît jamais dans le stockage.
    expect(stockage._valeurs.values.any((v) => v == '4821'), isFalse);

    expect(await service.verifierPin('4821'), isTrue);
    expect(await service.verifierPin('0000'), isFalse);

    expect(await service.question(), 'Nom de mon premier client ?');
    // La réponse est insensible à la casse et aux espaces superflus.
    expect(await service.verifierReponse('  aya  '), isTrue);
    expect(await service.verifierReponse('mauvaise réponse'), isFalse);

    await service.reinitialiserPin('9999');
    expect(await service.verifierPin('4821'), isFalse);
    expect(await service.verifierPin('9999'), isTrue);

    await service.supprimerVerrouillage();
    expect(await service.pinConfigure(), isFalse);
    expect(await service.verifierPin('9999'), isFalse);
  });
}
