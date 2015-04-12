# takahashi
Generate Takahashi-style PDF presentations from simple text outlines

Warning: in its current shape the code is nearly unusable, as it consists of a 
single, monolithic Perl script full of bad hacks. It was written rather quickly 6 years ago, and I've never gotten around rewriting it. 

This is a Perl application to turn a simple text definition file into a latex beamer presentation.
 As this is intended for the so-called Takahashi style of presentation which consists of
 a few or even only one word (or perhaps an image or an equation) per slide,
 the text definition file is also very simple in structure.
(see example.src)

## Syntax rules:

Comment lines begin with '#', they will be ignored.

Normal text in a line will be typeset in a line of their own in the presentation as well.

Font sizes are chosen so that the text fills up the viewing area.
Check the output and reword if you don't like the default layout.

Alternatively, manual font sizes are possible with the character '@'. 
If a normal line is terminated by the '@' char and an integer, 
then that integer will be substituted for the font size (in points) for that line. 
If the line is terminated with '@-' then the line will be typeset with the font size of the preceding line.

An empty line signifies a new slide.

The dot character (.) denotes special mode, which can be one of the following:
image, gnuplot and tex.
