Class dc.codemonitor.ExampleCsp
{

ClassMethod MonitorCSP(parameters As %DynamicObject = {{}}) As %Status
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

        ; If you need to monitor a CSP page, it's not a problem.  
        ; Like a class, once compiled, the CSP generate a class and routine.  
        ; ex: /csp/user/menu.csp --> class: csp.menu --> routine: csp.menu.1
        Set monitor.routines = $ListBuild("csp.menu.1")

        ; CSP need %session, %request and %response object
        ; just create the objects and set the parameters with the values needed by the CSP page
        Set %request = ##class(%CSP.Request).%New()
        ; Set %request.Data("<param_name>", 1) = <value>
        
        Set %request.CgiEnvs("SERVER_NAME") = "localhost"
        Set %request.URL = "/csp/user/menu.csp"

        Set %session = ##class(%CSP.Session).%New(1234)
        ;Set %session.Data("<data_name>", 1) = <value>

        Set %response = ##class(%CSP.Response).%New()
            

        $$$TOE(sc,monitor.startMonitoring())
		
        Try {
            ; Not required, but if you want to avoid write the CSP Page content in the terminal
            ; you can use the IORedirect class to redirect the output to null
            ; this tool is availalbe on OpenExchange, you can install it by using zpm "install io-redirect"
            ; comment IORedirect lines if you don't want to use it
            ; Do ##class(IORedirect.Redirect).ToNull() 
            
            ; Call the CSP page using the OnPage ClassMethod, juste like this
            Do ##class(csp.menu).OnPage()
            
            ; restore the output
            ; Do ##class(IORedirect.Redirect).RestoreIO()

            Do monitor.stopMonitoring()
        }
        Catch ex {
            Do monitor.stopMonitoring()
            ; Do ##class(IORedirect.Redirect).RestoreIO()
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
