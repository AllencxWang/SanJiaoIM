import Foundation
import SanJiaoCore

@main
struct SanJiaoBuilder {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3 else {
            FileHandle.standardError.write(Data("usage: sanjiao-builder <input.cin> <output.bin>\n".utf8))
            exit(2)
        }
        let input = URL(fileURLWithPath: args[1])
        let output = URL(fileURLWithPath: args[2])
        let raws = try CinParser.parse(fileURL: input)
        let entries = BuilderPipeline.assemble(from: raws)
        let bin = try LexiconWriter.serialize(entries: entries)
        try bin.write(to: output)
        print("wrote \(entries.count) entries → \(output.path)")
    }
}
