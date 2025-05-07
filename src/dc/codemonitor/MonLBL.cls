/// Cette classe permet de monitorer des routines ou des classes en utilisant le package %Monitor.System.LineByLine
/// Les informations collectées sont les suivantes : "RtnLine","GloRef","Time" et "TotalTime"
/// Les routines ou classes à monitorer sont définies dans la liste "routines" et celles-ci doivent être compilées avec les flags "ck"
/// Les résultats sont exportés dans des fichiers CSV
/// Exemple d'utilisation
/// Set mon = ##class(dc.codemonitor.MonLBL).%New()
/// Set mon.routines = $ListBuild("BDOC.UserId.1")
/// Do mon.startMonitoring()
/// ; code à monitorer
/// Do mon.stopMonitoring()
Class dc.codemonitor.MonLBL Extends %RegisteredObject
{

/// Répertoire utilise pour exporter les fichiers résultats CSV
/// Par défaut le répertoire /mgr/Temp/ de l'installtion IRIS
Property directory As %String [ InitialExpression = {##class(%File).NormalizeDirectory(##class(%SYS.System).TempDirectory())} ];

/// Liste des routines que l'on souhaite monitorer
/// Si vous souhaitez monitorer une classe, il faut mettre dans la liste sa forme "int"
/// ex : BDOC.UserId -> BDOC.UserId.1 (dans le cas de classe avec beaucoup de code il se peut qu'il existe des routines de dépassements .2, .3 etc...
/// Il est nécessaire que le code que l'on souhaite monitorer soit compiler avec les flags "ck"
Property routines As %List;

/// Si autoCompile est à 1, check si les routines sont compilées avec les flag "ck" sinon on recompile.
Property autoCompile As %Boolean [ InitialExpression = 0 ];

/// Par défaut les informations collectées sont "RtnLine","GloRef","Time" et "TotalTime"
/// La liste des métrics disponible peut être affichée à l'aide de la commande : Do ##class(%Monitor.System.LineByLine).GetMetrics(3)
Property metrics As %List [ InitialExpression = {$ListBuild("RtnLine","GloRef","Time","TotalTime")} ];

/// { "startDateTime":(startDT), "timing" : (timing), "lines" : (lines), "gloRefs" : (gloRefs) }
Property perf As %DynamicObject;

Property temp As %DynamicObject [ Private ];

/// Si vous voulez que le point decimal soit une "," mettez cet property à 1
/// cela peut vous facilitez la vie sous Excel
Property decimalPointIsComma As %Boolean [ InitialExpression = 1 ];

/// Pour ne collecter que le timing, lines et global refs sans les metrics ligne par ligne, mettez ce flag à false
Property metricsEnabled As %Boolean [ InitialExpression = {$$$YES} ];

Method startMonitoring() As %Status
{
	Set sc = $$$OK
	; Stop au cas ou l'on aurait déjà un monitoring en cours d'exécution...
	Do ##class(%Monitor.System.LineByLine).Stop()
	
	If ..autoCompile {
		Set sc = ..autoCompile()
		If $$$ISERR(sc) Return sc
	}
	
	Do $SYSTEM.Process.EnableDiskReadTiming()
	Do $SYSTEM.Process.ResetDiskReadTiming()
	
	If ..metricsEnabled {
		Set sc = ##class(%Monitor.System.LineByLine).Start(..routines, ..metrics, $ListBuild($Job))
	}
	
	Set cpuTime = $SYSTEM.Process.GetCPUTime(), systemCPUTime = $Piece(cpuTime,",",1), userCPUTime = $Piece(cpuTime,",",2)
	Set ..perf = { "startDateTime":($ZDateTime($Horolog, 3, 1)) }
	Set ..temp = { "timing" : ($ZHorolog), "lines" : ($zu(67,8,$job)), "gloRefs" : ($$$GlobalRefs),"systemCPUTime" : (systemCPUTime), "userCPUTime" : (userCPUTime)}
	
	Set ^||CodeMonitor = 1 ; peut être utile si on veut mettre des if dans le code seulement si nous sommes dans le monitoring du code
	
	Return sc
}

Method stopMonitoring() As %Status
{
	Set cpuTime = $SYSTEM.Process.GetCPUTime(), systemCPUTime = $Piece(cpuTime,",",1), userCPUTime = $Piece(cpuTime,",",2)
	Set ..perf.systemCPUTime = systemCPUTime - ..temp.systemCPUTime
	Set ..perf.userCPUTime = userCPUTime - ..temp.userCPUTime
	Set ..perf.timing = $ZHorolog - ..temp.timing
	Set ..perf.lines = $zu(67,8,$job) - ..temp.lines
	Set ..perf.gloRefs = $$$GlobalRefs - ..temp.gloRefs
	Set ..perf.diskReadInMs = $SYSTEM.Process.DiskReadMilliseconds()
	Do $SYSTEM.Process.DisableDiskReadTiming()
	
	Set sc = $$$OK, ptr = 0
	
	If ..metricsEnabled {
		Set directory = ##class(%File).NormalizeDirectory(..directory)
		
		While $ListNext(..routines, ptr, routine) {
			Do ..ExportMetrics(routine, directory _ routine _ ".csv", ..decimalPointIsComma)
		}
			
		Set sc = ##class(%Monitor.System.LineByLine).Stop()
	}
	
	Write !,"* Perf results : ",!
	Set formatter = ##class(%JSON.Formatter).%New()
	Do formatter.Format(..perf)
	Write !
	
	Set ^||CodeMonitor = 0
	
	Return sc
}

Method autoCompile() As %Status
{
	Set sc = $$$OK
	Set ptr = 0
	While $ListNext(..routines, ptr, routine) {
		If $Data(^ROUTINE(routine)) Continue	; on peut skip on a bien le code
		Set className = $Extract(routine, 1, *-2)
		If '##class(%Dictionary.ClassDefinition).%ExistsId(className) Continue
		Set sc = $$$ADDSC(sc,$SYSTEM.OBJ.Compile(className, "ck"))
	}
	Return sc
}

ClassMethod ExportMetrics(routine As %String, csvFile As %String = {##class(%File).NormalizeDirectory(##class(%SYS.System).TempDirectory())_routine_".csv"}, decimalPointIsComma As %Boolean = {$$$NO}) As %Status
{
	Set sc = $$$OK
	
	If ##class(%File).Exists(csvFile) {
		Do ##class(%File).Delete(csvFile)
	}
	
	Set metrics=##class(%Monitor.System.LineByLine).GetMetrics()
	Set cnt=$Length(metrics, ",")
	
	Set file = ##class(%Stream.FileCharacter).%New()
	Do file.LinkToFile(csvFile)
	Do file.WriteLine("LineByLine;"_$Replace(metrics, ",", ";")_";Code")
	
	
	Set rset=##class(%ResultSet).%New("%Monitor.System.LineByLine:Result")
	Do rset.Execute(routine)
	While rset.Next() {
		Set line = $Increment(line)
		Set data = rset.GetData(1)
		If decimalPointIsComma {
			Set data = $Replace(data,".",",")
		}
		Set lineCode = $Replace($Get(^ROUTINE(routine, 0, line)), $Char(9), "    ")
		Set csvEscapeCode = """" _ $Replace(lineCode, """","""""") _""";"
		Do file.WriteLine(line _ ";" _$ListToString(data, ";") _";" _csvEscapeCode)
	}
	Do rset.Close()
	
	Do file.%Save()
	
	Write !,"* Metrics are exported to ",csvFile
	
	Return sc
}

}
