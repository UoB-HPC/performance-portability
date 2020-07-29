import $ivy.`com.github.pathikrit::better-files:3.8.0`, better.files._


val pwd = File.currentWorkingDirectory
println(s"In $pwd")

val apps = pwd.list.filter(_.isDirectory).toVector

sealed trait App {
	def target: String
	def compiler: String
	def model: String
	def name: String
}
case class BabelStream(large: Boolean, target: String, compiler: String, model: String) extends App {
	def name = if (large) "BabelStream(2^29)" else "BabelStream"
}
case class CloverLeaf(target: String, compiler: String, model: String) extends App {def name = "CloverLeaf"}
case class TeaLeaf(target: String, compiler: String, model: String) extends App {def name = "TeaLeaf"}
case class MiniFMM(target: String, compiler: String, model: String) extends App {def name = "MiniFMM"}
case class Neutral(target: String, compiler: String, model: String) extends App {def name = "Neutral"}



val cmark = " - [x]"

apps.foreach { app =>

	val outDir = app / "results"
	val results = outDir.glob("*.out").filterNot(_.isHidden).map(_.name).toVector
	println(s"${cmark} ${app.name}")

	val (bad, good) = results.partitionMap {
		case f@s"BabelStream-large-${target}_${compiler}_${model}.out" => Right((outDir / f) -> BabelStream(true, target, compiler, model))
		case f@s"BabelStream-${target}_${compiler}_${model}.out"       => Right((outDir / f) -> BabelStream(false, target, compiler, model))

		case f@s"CloverLeaf-${target}_${compiler}_${model}.out" => Right((outDir / f) -> CloverLeaf(target, compiler, model))
		case f@s"TeaLeaf-${target}_${compiler}_${model}.out"    => Right((outDir / f) -> TeaLeaf(target, compiler, model))
		case f@s"MiniFMM-${target}_${compiler}_${model}.out"    => Right((outDir / f) -> MiniFMM(target, compiler, model))
		case f@s"Neutral-${target}_${compiler}_${model}.out"    => Right((outDir / f) -> Neutral(target, compiler, model))

		case bad => Left(bad)
	}
	if (bad.nonEmpty) {
		println(s"Bad files: ${bad}")
	}

	// TODO generate a table
	val formatted = good
		.groupMap(_._2.name) { case (file, app) => s"${app.target} ${app.model}".padTo(20, ' ') +  s"(${app.compiler})".padTo(15, ' ') + f"${file.lineCount}L @ ${file.size.toDouble/1024}%2.2f KB" }
		.toVector
		.sortBy(_._1)
		.map { case (k, v) => s"  ${cmark} ${k}: ${v.sorted.map(s"${cmark} " + _).mkString("\n    ", "\n    ", "")}" }

	println(formatted.mkString("\n"))

}