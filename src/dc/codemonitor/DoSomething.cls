Class dc.codemonitor.DoSomething Extends %RegisteredObject
{

/// Just for testing code monitoring
ClassMethod GenerateNumber(n As %Integer = 1000000)
{
    For i=1:1:n {
        Set number = $Random(100000)
        Set isOdd = number # 2
    }

    Return
}

}
