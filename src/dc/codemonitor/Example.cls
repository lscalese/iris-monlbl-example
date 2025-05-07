Class dc.codemonitor.Example
{

ClassMethod MonitorGenerateNumber(parameters As %DynamicObject) As %Status
{
    Set sc = $$$OK
    Try {

        Write "* Parameters :", !
        Set formatter = ##class(%JSON.Formatter).%New()
        Do formatter.Format(parameters)
        Write !
        
        Set monitor = ##class(dc.codemonitor.MonLBL).%New()
        ;Warning : if you use the monitoring in a production environment, you should
        ;set autoCompile to $$$NO and plan to compile the code you want to monitor yourself. 
        Set monitor.autoCompile = $$$YES
        Set monitor.metricsEnabled = $$$YES
        Set monitor.directory = ##class(%File).NormalizeDirectory(##class(%SYS.System).TempDirectory())

        ;Insert the dc.codemonitor.DoSomething class in the list of monitored classes.
        ;We need to use the "int" routine related to the class
        ;If you don't know the routine name, you can use the following command:
        ;Do $SYSTEM.OBJ.Compile("dc.codemonitor.DoSomething","ck")
        ;and the the line starting with "Compiling routine" will give you the name of the routine.
        ;
        ;Compilation started on 05/07/2025 21:16:07 with qualifiers 'ck'
        ;Compiling class dc.codemonitor.DoSomething
        ;Compiling routine dc.codemonitor.DoSomething.1
        ;Compilation finished successfully in 0.008s.
        Set monitor.routines = $ListBuild("dc.codemonitor.DoSomething.1")

        $$$TOE(sc,monitor.startMonitoring())
		
        Try {
            Do ##class(dc.codemonitor.DoSomething).GenerateNumber(parameters.number)

            ;Important: stop the monitoring
            ;if you don't stop the monitoring, the system will continue to monitor for this process
            Do monitor.stopMonitoring()
        }
        Catch ex {
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

}
