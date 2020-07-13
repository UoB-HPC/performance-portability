import $ivy.`com.github.pathikrit::better-files:3.8.0`, better.files._


val pwd = File.currentWorkingDirectory
println(s"In $pwd")

val apps = pwd.list.filter(_.isDirectory).toVector

sealed trait App {
    def target: String
    def compiler: String
    def model: String
    def name : String
}
case class BabelStream(large : Boolean,  target: String, compiler: String, model: String) extends App{
    def name = if(large) "BabelStream(2^29)" else "BabelStream"
}

val cmark = " - [x]"

apps.foreach {app => 

    val results = (app / "results").glob("*.out").filterNot(_.isHidden).map(_.name).toVector
    println(s"${cmark} ${app.name}")

    val (bad, good) = results.partitionMap {
        case s"BabelStream-large-${target}_${compiler}_${model}.out" => Right ( BabelStream(true, target, compiler, model) ) 
        case s"BabelStream-${target}_${compiler}_${model}.out" => Right ( BabelStream(false, target, compiler, model) ) 
        case bad => Left(bad)
    }
    if(bad.nonEmpty){
        println(s"Bad files: ${bad}")
    }

    val formatted = good
        .groupMap(_.name) { app => s"${app.target} ${app.model} (${app.compiler})" }
        .toVector
        .sortBy(_._1)
        .map{ case (k, v) => s"  ${cmark} ${k}: ${v.sorted.map(s"${cmark} " + _).mkString("\n    ", "\n    ", "")}" }
         
    println(formatted.mkString("\n"))

}