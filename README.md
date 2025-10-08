# LAPS Tool - Outil graphique de récupération et traçabilité v3.1

Cette application fournit une interface graphique (GUI) pour récupérer et gérer les mots de passe LAPS (Local Administrator Password Solution) d'ordinateurs de domaine. Elle permet aux utilisateurs autorisés de générer un mot de passe d'administrateur local, de forcer sa date d'expiration, et d'exporter une trace complète des opérations avec un guide d'utilisation.

L'application gère les erreurs de manière détaillée, effectue un diagnostic des permissions avant l'exécution, et impose un motif de demande pour garantir une traçabilité complète.

## Fonctionnalités

- Récupération du mot de passe LAPS via l'interface graphique.
- Champs **nom de l'ordinateur** et **motif de la demande** avec validation (8 caractères minimum).
- Sélection de la durée de validité du mot de passe (4h, 8h, 12h, 24h, 1 mois).
- Export d'un fichier texte contenant toutes les informations de traçabilité.
- Guide d'utilisation inclus dans l'export pour aider les utilisateurs à s'authentifier via UAC.
- Barre de progression détaillée montrant les étapes de l'opération.
- Diagnostic des erreurs avec retour précis des permissions manquantes.
- Bouton de rappel "Nouvelle demande" pour réinitialiser entièrement l'interface.
- Compatible avec PowerShell 5.1 et versions ultérieures.
- Interface désactivée pendant l'exécution pour éviter les doubles clics.

## Prérequis

- PowerShell 5.1+
- Module Windows LAPS installé sur la machine cliente.
- Droits **lecture** et **reset** LAPS configurés dans l'Active Directory pour l'OU des postes.
- Accès réseau au contrôleur de domaine pour interroger l'annuaire AD.

Aucun autre module externe n'est nécessaire. L'application repose uniquement sur les fonctionnalités natives de Windows et .NET.

## Fonctionnement

1. Saisissez le **nom de l'ordinateur** (FQDN ou NetBIOS).
2. Entrez un **motif de la demande** (8 caractères minimum).
3. Choisissez la **durée de validité** souhaitée dans la liste déroulante.
4. Cliquez sur **Générer le mot de passe**.
5. L'application affiche une barre de progression et le statut de chaque étape.
6. Une fois terminée, cliquez sur **Exporter les informations** pour générer un fichier texte signé.
7. Pour une nouvelle demande, cliquez sur **Nouvelle demande**.

Le fichier exporté est nommé `LAPS_INFO_NOM_POSTE_YYYYMMDDHHMM.txt` et contient :
- L'utilisateur ayant effectué la demande
- L'ordinateur cible
- Le motif
- La date de génération et d'expiration
- Le mot de passe généré
- Un guide d'utilisation pour l'authentification via UAC

