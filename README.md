# Sitebuilder
A simple static page generator. Give it a template and a series of Markdown text files and it'll produce a full website.

## Usage:
* sitebuilder.sh [-b &lt;templatename&gt;] [-c &lt;dir&gt;] [-p &lt;dir&gt;] [-r &lt;path&gt;] [-t &lt;dir&gt;] [-w &lt;dir&gt;]
* sitebuilder.sh -h

## Options:
*  -b &lt;templatename&gt; The base template name to use (default "template.html")
*  -c &lt;dir&gt;	Content Directory (Default "Content")
*  -d		Print the full documentation
*  -f   FORCE update of all documents (Deletes all previous documents)
*  -g   Load a config file. (Default none)
*  -o   Offset directory - used to put everything into a sub-directory (Default "/")
*  -p &lt;dir&gt;	Public Directory (Default "Public")
*  -r &lt;path&gt;	Path to root of site. Default is to use the current directory.
*  -t &lt;dir&gt;	Templates directory (Default "Templates")
*  -w &lt;dir&gt;	Web directory (Default "www")
*  -v		VERBOSE. List all processing and messages
*  -h		Show help


# Sitebuilder

## Overview:

A simple static page generator. Give it a template and a series of Markdown text files and it'll produce a full website.

## Directory Structure:

*Content*	- Contains directories and files which are the basic content of the site.

*Public*	- All files which are to be made public and unchanged. Typically graphics/images, Stylesheets, .pdf files and other non-mutable content.

*Templates* 	- HTML templates.

*www* 		- Where all the resulting files end up.

All of these locations can be specified as parameters when running SiteBuilder, the default is that these locations exist in the current working directory.

SiteBuilder will look for an "index.txt" (or "index.md") file in all directories to be used as the content for that directory. Directories and files may be preceeded with a number followed by a dot (.) to order the contents appropriately. These values are removed from the resulting items.

## Files:

*config* - Resides in the Template directory. Can store a number of default global values.

All files ending with .txt or .md in the Content directory will be converted to .html files in the www directory in the same directory structure.

Files may be preceeded by a number followed by a dot eg. 1.First Page.txt, 2.Second Page.txt etc. to automatically sort the entries. The number and dot are removed during processing leaving only the the text after the dot, but the order will be retained. Useful for Next/Prev pointers.

## Content Structure:

An example file can be as simple as:

```
@Template OtherTemplate.html
@Title Example Title
@Tags This, That, The Other
@Body
Here is the main content of the page.
```

A variable is declared with an at "@" at the start of the line. Everything after the first space is considered as the various content upto another @ entry or the end of the file. Variables are usually case sensitive, so it's best to be consistent in how they are defined.

If the Template variable is modified then it overrides the default "Template:" value in the config.data file.

## Variables:

To use a variable within a template, simply enclose it within double curly braces. eg. {{Title}}

There is also an optional way of using variables in case they have NOT been defined, or the value is nothing (""). Use {{Title|Some title}} to use "Some title" should one not be defined.

There is also an inclusion value that if a variable HAS been defined, and is not empty ("") then replace it with something else. Use {{Tags&gt;These tags have been defined {{Tags}}}} so that if the "Tags" variable has been defined replace it with some extra text.

NB. Variable names are case-sensitive. Do not use { or } values as standalone values within the replacements. The results would be unpredictable.

Only the variable "Body" will be parsed as Markdown. Everything else will be passed as-is.

## Reserved List Variables:

There are a number of variables which are computed automatically based on the directory structure of the Content directory. These are automatically created as un-ordered lists and may be stylised with CSS.

{{PrimaryNavigation}} - Based on the root of the Content Directory. No link to the Home directory.

{{SecondaryNavigation}} - Based on the directory structure for each underlying directory, used within pages in that specifc directory. Not used in the root directory.

{{Navigation}} - A complete heirarchical directory and file structure.

{{BreadCrumbs}} - A directory list to the current working file.

{{Include|&lt;filename&gt;}} - which will include &lt;filename&gt; from the Templates directory. In this way you can also include additional shared elements based on defined variables.

{{Digest}} or {{DigestReverse}} - This will go through all of the entries in the current directory and use the variable values of "@Digest" as entries. If this is added to the Index entry then all other files could have a single line which will be included in the output. {{Digest}} sorts alphabetically, {{DigestReverse}} sorts in reverse order. If a file does not have a @Digest value then it simply won't be included. This is only computed at run-time. If you add a new file, then you'll also need to update the file containing the {{Digest}} command for it to be included.

In addition, each top level &lt;ul&gt; entry is given the ID PrimaryNavigation, SecondayNavigation and Navigation as appropriate.

## Reserved Non-list variables:

{{NavigateNext}}, {{NavigatePrevious}} - The filename of the next or previous document within the directory. Blank if no such document exists.

{{NavigateNextName}}, {{NavigatePreviousName}} - The real document name to the next or previous document within the directory. Blank if no such document exists.

{{TagList}} - List of Tags used throughout the site. NB. Adding a new page with an additional tag will NOT update other (older) documents. Use the -f flag to FORCE a site-wide update.

NB. Do NOT embed multiple variable replacements inside other variables.

DO NOT do this:
  {{NavigateNext&gt;&lt;a href="{{NavigateNext}}"&gt;&lt;span class="next"&gt;{{NavigateNextName}}&lt;/span&gt;&lt;/a&gt;}}

Do this instead:
  @NavNext &lt;a href="{{NavigateNext}}"&gt;&lt;span class="next"&gt;{{NavigateNextName}}&lt;/span&gt;&lt;/a&gt;
  {{NavigateNext&gt;{{NavNext}}}}

In this way, if a NavigateNext (or NavigatePrevious) value is detected then the relevant value would be included. If the NavigatePrevious value is blank, then the whole inclusion value would be skipped. If you need to include multiple replacement values, then create intermediate variables instead.

The regex is not forgiving! 

