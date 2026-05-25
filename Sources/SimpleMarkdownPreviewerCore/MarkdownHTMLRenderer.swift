import Foundation
import Markdown

public struct MarkdownHTMLRenderer {
    public init() {}

    public func render(_ source: String, documentURL: URL) throws -> String {
        let policy = ResourcePolicy(documentURL: documentURL)
        let document = Document(parsing: source)
        var visitor = SafeHTMLVisitor(policy: policy)
        return visitor.visit(document)
    }
}

private struct SafeHTMLVisitor: MarkupVisitor {
    typealias Result = String

    let policy: ResourcePolicy
    var inTableHead = false
    var tableColumnAlignments: [Table.ColumnAlignment?] = []
    var currentTableColumn = 0

    mutating func defaultVisit(_ markup: Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Document) -> String {
        document.children.map { visit($0) }.joined(separator: "\n")
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>\n" + defaultVisit(blockQuote) + "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let language = codeBlock.language?.htmlEscaped() ?? "plaintext"
        return "<pre><code class=\"language-\(language)\">\(codeBlock.code.htmlEscaped())</code></pre>\n"
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = min(max(heading.level, 1), 6)
        return "<h\(level)>" + defaultVisit(heading) + "</h\(level)>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        html.rawHTML.htmlEscaped()
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        let checkbox = listItem.checkbox.map { checked in
            "<input type=\"checkbox\" disabled\(checked == .checked ? " checked" : "")> "
        } ?? ""
        let className = listItem.checkbox == nil ? "" : " class=\"task-list-item\""
        return "<li\(className)>" + checkbox + defaultVisit(listItem) + "</li>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        "<ol>\n" + defaultVisit(orderedList) + "</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>\n" + defaultVisit(unorderedList) + "</ul>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>" + defaultVisit(paragraph) + "</p>\n"
    }

    mutating func visitTable(_ table: Table) -> String {
        tableColumnAlignments = table.columnAlignments
        let content = defaultVisit(table)
        tableColumnAlignments = []
        return "<table>\n" + content + "</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> String {
        inTableHead = true
        currentTableColumn = 0
        let content = defaultVisit(tableHead)
        inTableHead = false
        return "<thead>\n<tr>\n" + content + "</tr>\n</thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> String {
        let content = defaultVisit(tableBody)
        return content.isEmpty ? "" : "<tbody>\n" + content + "</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> String {
        currentTableColumn = 0
        return "<tr>\n" + defaultVisit(tableRow) + "</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> String {
        let element = inTableHead ? "th" : "td"
        let attributes = tableCellAttributes(tableCell)
        currentTableColumn += 1
        return "<\(element)\(attributes)>" + defaultVisit(tableCell) + "</\(element)>\n"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>" + inlineCode.code.htmlEscaped() + "</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>" + defaultVisit(emphasis) + "</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>" + defaultVisit(strong) + "</strong>"
    }

    mutating func visitImage(_ image: Image) -> String {
        guard let source = image.source,
              let url = try? policy.localImageURL(for: source) else {
            return ""
        }
        let alt = defaultVisit(image)
        return "<img src=\"\(url.absoluteString.htmlEscaped())\" alt=\"\(alt.htmlEscaped())\">"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        inlineHTML.rawHTML.htmlEscaped()
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLink(_ link: Link) -> String {
        guard let destination = link.destination,
              let url = URL(string: destination),
              let allowed = policy.allowedExternalURL(url) else {
            return defaultVisit(link)
        }
        return "<a href=\"\(allowed.absoluteString.htmlEscaped())\">" + defaultVisit(link) + "</a>"
    }

    mutating func visitText(_ text: Text) -> String {
        text.string.htmlEscaped()
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>" + defaultVisit(strikethrough) + "</del>"
    }

    private func tableCellAttributes(_ tableCell: Table.Cell) -> String {
        var attributes = ""
        if currentTableColumn < tableColumnAlignments.count,
           let alignment = tableColumnAlignments[currentTableColumn] {
            attributes += " align=\"\(alignment)\""
        }
        if tableCell.rowspan > 1 {
            attributes += " rowspan=\"\(tableCell.rowspan)\""
        }
        if tableCell.colspan > 1 {
            attributes += " colspan=\"\(tableCell.colspan)\""
        }
        return attributes
    }
}
