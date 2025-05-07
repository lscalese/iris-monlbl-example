# MonLBL - Utilitaire de monitoring de code ObjectScript ligne par ligne

## Introduction

MonLBL est un outil permettant d'analyser des performances d'exécution de code ObjectScript ligne par ligne. Cet utilitaire s'appuie sur le package `%Monitor.System.LineByLine` d'InterSystems IRIS pour collecter des métriques précises sur l'exécution de routines, classes ou CSP.

## Fonctionnalités

L'utilitaire permet de collecter plusieurs types de métriques :
- **RtnLine** : Nombre d'exécutions de la ligne
- **GloRef** : Nombre de références globales générées par la ligne
- **Time** : Temps d'exécution de la ligne
- **TotalTime** : Temps total d'exécution incluant les sous-routines appelées

En plus des métriques par ligne, MonLBL collecte des statistiques globales :
- Temps d'exécution total
- Nombre total de lignes exécutées
- Nombre total de références globales
- Temps CPU système et utilisateur : 
  * Le temps CPU utilisateur correspond au temps passé par le processeur à exécuter le code de l'application
  * Le temps CPU système correspond au temps passé par le processeur à exécuter des opérations du système d'exploitation (appels système, gestion mémoire, I/O)
- Temps de lecture disque

## Prérequis

Pour pouvoir monitorer du code avec MonLBL :
1. Les routines ou classes à analyser doivent être compilées avec les flags "ck"
2. Pour les classes, il faut utiliser leur forme "int" (par exemple, "USER.Class.1" au lieu de "USER.Class")

## ⚠️ Mise en garde importante

L'utilisation du monitoring ligne par ligne a un impact  sur les performances du serveur. Il est important de respecter les recommandations suivantes :

- N'utilisez cet outil que sur un ensemble limité de code et de processus (idéalement de l'exécution ponctuel dans un terminal) 
- Évitez son utilisation sur un serveur de production 
- Utilisez de préférence cet outil dans un environnement de développement ou de test 

Ces précautions sont essentielles pour éviter des problèmes de performance qui pourraient affecter les utilisateurs ou les systèmes en production.
Sachez que le code monitoré s'exécute environ 15-20% plus lentement que s'il ne l'est pas. 

## Utilisation

### Exemple basique

```objectscript
// Création d'une instance de MonLBL
Set mon = ##class(dc.codemonitor.MonLBL).%New()

// Définition des routines à monitorer
Set mon.routines = $ListBuild("MaClasse.1")

// Démarrage du monitoring
Do mon.startMonitoring()

// Code à analyser...
// ...

// Arrêt du monitoring et génération des résultats
Do mon.stopMonitoring()
```

### Options de configuration

L'utilitaire offre plusieurs options configurables :

- **directory** : Répertoire où seront exportés les fichiers CSV (par défaut le répertoire Temp d'IRIS)
- **autoCompile** : Recompile automatiquement les routines avec les flags "ck" si nécessaire
- **metrics** : Liste personnalisable des métriques à collecter
- **decimalPointIsComma** : Utilise la virgule comme séparateur décimal pour une meilleure compatibilité avec Excel
- **metricsEnabled** : Active ou désactive la collecte des métriques ligne par ligne

## Exemple d'utilisation avancée

Voici un exemple plus complet disponible dans la classe `dc.codemonitor.Example` :

```objectscript
ClassMethod MonitorGenerateNumber(parameters As %DynamicObject) As %Status
{
    Set sc = $$$OK
    Try {
        // Affichage des paramètres reçus
        Write "* Parameters :", !
        Set formatter = ##class(%JSON.Formatter).%New()
        Do formatter.Format(parameters)
        Write !
        
        // Création et configuration du moniteur
        Set monitor = ##class(dc.codemonitor.MonLBL).%New()
        
        // ATTENTION : en environnement de production, définissez autoCompile à $$$NO
        // et compilez manuellement le code à monitorer
        Set monitor.autoCompile = $$$YES
        Set monitor.metricsEnabled = $$$YES
        Set monitor.directory = ##class(%File).NormalizeDirectory(##class(%SYS.System).TempDirectory())
        Set monitor.decimalPointIsComma = $$$YES

        // Configuration de la routine à monitorer (forme "int" de la classe)
        // Pour trouver le nom exact de la routine, utilisez la commande :
        // Do $SYSTEM.OBJ.Compile("dc.codemonitor.DoSomething","ck")
        // La ligne "Compiling routine XXX" vous donnera le nom de la routine
        Set monitor.routines = $ListBuild("dc.codemonitor.DoSomething.1")

        // Démarrage du monitoring
        $$$TOE(sc, monitor.startMonitoring())
        
        // Exécution du code à monitorer avec gestion des erreurs
        Try {
            Do ##class(dc.codemonitor.DoSomething).GenerateNumber(parameters.Number)

            // Important : toujours arrêter le monitoring
            Do monitor.stopMonitoring()
        }
        Catch ex {
            // Arrêt du monitoring même en cas d'erreur
            Do monitor.stopMonitoring()
            Throw ex
        }
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Do $SYSTEM.Status.DisplayError(sc)
    }

    Return sc
}
```

Cet exemple montre plusieurs bonnes pratiques importantes :
- Utilisation d'un bloc Try/Catch pour gérer les erreurs
- Arrêt systématique du monitoring, même en cas d'erreur
- Documentation sur la façon de trouver le nom exact de la routine correspondant à une classe à monitorer
- Paramétrage complet du moniteur

## Exemple d'utilisation avec des pages CSP

MonLBL permet également de monitorer des pages CSP. Voici un exemple disponible dans la classe `dc.codemonitor.ExampleCsp` :

```objectscript
ClassMethod MonitorCSP(parameters As %DynamicObject = {{}}) As %Status
{
    Set sc = $$$OK
    Try {
        // Affichage des paramètres reçus
        Write "* Parameters :", !
        Set formatter = ##class(%JSON.Formatter).%New()
        Do formatter.Format(parameters)
        Write !
        
        // Création et configuration du moniteur
        Set monitor = ##class(dc.codemonitor.MonLBL).%New()
        Set monitor.autoCompile = $$$YES
        Set monitor.metricsEnabled = $$$YES
        Set monitor.directory = ##class(%File).NormalizeDirectory(##class(%SYS.System).TempDirectory())
        Set monitor.decimalPointIsComma = $$$YES

        // Pour monitorer une page CSP, on utilise la routine générée
        // Exemple: /csp/user/menu.csp --> classe: csp.menu --> routine: csp.menu.1
        Set monitor.routines = $ListBuild("csp.menu.1")

        // Les pages CSP nécessitent les objets %session, %request et %response
        // On crée ces objets avec les paramètres nécessaires
        Set %request = ##class(%CSP.Request).%New()
        // Configurer les paramètres de requête si nécessaire
        // Set %request.Data("<param_name>", 1) = <value>
        Set %request.CgiEnvs("SERVER_NAME") = "localhost"
        Set %request.URL = "/csp/user/menu.csp"

        Set %session = ##class(%CSP.Session).%New(1234)
        // Configurer les données de session si nécessaire
        // Set %session.Data("<data_name>", 1) = <value>

        Set %response = ##class(%CSP.Response).%New()
            
        // Démarrage du monitoring
        $$$TOE(sc, monitor.startMonitoring())
        
        Try {
            // Pour éviter d'afficher le contenu de la page CSP dans le terminal,
            // on peut utiliser la classe IORedirect pour rediriger la sortie vers null
            // (nécessite l'installation via zpm "install io-redirect")
            Do ##class(IORedirect.Redirect).ToNull() 
            
            // Appel de la page CSP via sa méthode OnPage
            Do ##class(csp.menu).OnPage()
            
            // Restauration de la sortie standard
            Do ##class(IORedirect.Redirect).RestoreIO()

            // Arrêt du monitoring
            Do monitor.stopMonitoring()
        }
        Catch ex {
            // Toujours restaurer la sortie et arrêter le monitoring en cas d'erreur
            Do ##class(IORedirect.Redirect).RestoreIO()
            Do monitor.stopMonitoring()
           
            Throw ex
        }
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Do $SYSTEM.Status.DisplayError(sc)
    }

    Return sc
}
```

Points importants pour le monitoring des pages CSP :

1. **Identification de la routine** : Une page CSP est compilée en une classe et une routine. Par exemple, `/csp/user/menu.csp` génère la classe `csp.menu` et la routine `csp.menu.1`.

2. **Environnement CSP** : Il est nécessaire de créer les objets de contexte CSP (%request, %session, %response) pour que la page s'exécute correctement.

3. **Redirection de sortie** : Pour éviter que le contenu HTML ne s'affiche dans le terminal, on peut utiliser l'utilitaire IORedirect (disponible sur OpenExchange via `zpm "install io-redirect"`).

4. **Appel de la page** : L'exécution se fait via la méthode `OnPage()` de la classe générée.

## Exemple de sortie

Voici un exemple de sortie obtenue lors de l'exécution de la méthode `MonitorGenerateNumber` :

```
USER>d ##class(dc.codemonitor.Example).MonitorGenerateNumber({"number":"100"})
* Parameters :
{
  "number":"100"
}

* Metrics are exported to /usr/irissys/mgr/Temp/dc.codemonitor.DoSomething.1.csv
* Perf results :
{
  "startDateTime":"2025-05-07 18:45:42",
  "systemCPUTime":0,
  "userCPUTime":0,
  "timing":0.000205,
  "lines":19,
  "gloRefs":14,
  "diskReadInMs":"0"
}
```

On peut observer dans cette sortie :
1. L'affichage des paramètres d'entrée
2. La confirmation que les métriques ont été exportées dans un fichier CSV
3. Un résumé des performances globales au format JSON, incluant :
   - La date et l'heure de début
   - Le temps CPU système et utilisateur
   - Le temps d'exécution total
   - Le nombre de lignes exécutées
   - Le nombre de références globales
   - Le temps de lecture disque

## Interprétation des résultats CSV

Après l'exécution, des fichiers CSV (1 par routine dans le $ListBuild routines) sont générés dans le répertoire configuré. Ces fichiers contiennent :
- Le numéro de ligne
- Les métriques collectées pour chaque ligne
- Le code source de la ligne (attention si vous n'avez les classes du code à monitoré avec le flag "k", le code source ne sera pas disponible dans le fichier csv)

Voici un exemple du contenu d'un fichier CSV exporté (dc.codemonitor.DoSomething.1.csv) :

| Ligne | RtnLine | GloRef | Time | TotalTime | Code |
|-------|---------|--------|------|-----------|------|
| 1 | 0 | 0 | 0 | 0 | ` ;dc.codemonitor.DoSomething.1` |
| 2 | 0 | 0 | 0 | 0 | ` ;Generated for class dc.codemonitor.DoSomething.  Do NOT edit. 05/07/2025 10:16:07AM` |
| 3 | 0 | 0 | 0 | 0 | ` ;;59595738;dc.codemonitor.DoSomething` |
| 4 | 0 | 0 | 0 | 0 | ` ;` |
| 5 | 0 | 0 | 0 | 0 | `GenerateNumber(n=1000000) methodimpl {` |
| 6 | 1 | 0 | 0,000005 | 0,000005 | `    For i=1:1:n {` |
| 7 | 100 | 0 | 0,000019 | 0,000019 | `        Set number = $Random(100000)` |
| 8 | 100 | 0 | 0,000015 | 0,000015 | `        Set isOdd = number # 2` |
| 9 | 100 | 0 | 0,000013 | 0,000013 | `    }` |
| 10 | 1 | 0 | 0,000003 | 0,000003 | `    Return }` |

Dans ce tableau, nous pouvons analyser :
- **RtnLine** : Indique combien de fois chaque ligne a été exécutée (ici, les lignes 6 et 10 ont été exécutées une fois)
- **GloRef** : Montre les références globales générées par chaque ligne
- **Time** : Présente le temps d'exécution propre à chaque ligne
- **TotalTime** : Affiche le temps total incluant les appels à d'autres routines

Ces données peuvent être facilement importées dans un tableur pour analyse approfondie. Les lignes les plus coûteuses en termes de temps ou d'accès aux données peuvent ainsi être facilement identifiées.

## Conclusion

Le monitoring ligne par ligne est un outil précieux pour l'analyse de performance de code ObjectScript.  En identifiant précisément les lignes de code qui consomment le plus de ressources, il permet aux développeurs de gagner beaucoup de temps dans l'analyse de problèmes de lenteurs.  
