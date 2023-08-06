-- Convert .md links to .html 
function Link(el)
    el.target = string.gsub(el.target, "%.md", ".html")
    return el
end
