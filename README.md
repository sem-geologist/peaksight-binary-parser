# peaksight-binary-parser
Parsing description reverse engineered and writen in Kaitai Struct for reading the binary electron microprobe data files produced with Cameca Peaksight software.
It can fully or partly parse these types of binary files currently produced with Peaksight v4.2 (?) to v6.5:
* impDat
* wdsDat
* qtiDat
* calDat
* impSet
* wdsSet
* qtiSet
* calSet
* ovl


### Working example (for python as target language)
1. after downloading the repository, the file `cameca.ksy` needs to be compiled into target language with kaitai struct compiler.
   The "easiest" way is to go to kaitai struct web-ide (https://ide.kaitai.io/), drag and drop the file to ide and right click on the file in the list and navigate to `Generate parser` > and select the wished target language, which will present compiled source code in the tab onto hexviewer part of ide. The code can be selected there and copied to a blank new file.
   Let's say we selected the python, had copied the code to new blank document in your favorite plain text/code editor, and saved the file as `cameca.py`.
   The alternative way is to install kaitai struct compiler and use CLI in the path of the file:
   `ksc -t python cameca.ksy`, which will produce the `cameca.py` in the same directory (there is also an option to specify directory).
2. the generated code depends from kaitai runtime libarary. For python we can install the required kaitai struct runtime with `python -m pip install kaitaistruct` (in some debian based systems, such as Ubuntu, if using `python` comming with OS You may need to use `python3` instead of `python`)
3. in python interpreter (or scripts) or jupyter notebook we can parse given data as this:
  ```python
  from cameca import Cameca
  
  parsed_data = Cameca.from_file('path_to_file.wdsDat')
  ```
  when if we want to peak into datasets:
  ```python
  dts = parsed_data.content.datasets
  # if we want to print list of datasets with its setup name and comments:
  for i in dts:
     print(i.header.setup_file_name.text, i.comment.text)
  ```
4. To know the relations of objects in the object tree it is adviced to try parsing the binary files in kaitai web ide (in addition to previously drag-dropped cameca.ksy, You need to drag-drop your binary file which You want to parse) - there navigavable object tree can be consulted for writting code in the target language, albeit there will be some differences depending to common practices in target language. For example, python allows to access arguments directly in the objects, where most other languages will generate getter functions. Some languages change lower case into Camel case (for example, enumeration bundles translated to classes in python follow CamelCase rule-for classes, while idividual enumeration values are left as is in ksy). Code completion, such as in jupyter notebooks can be also useful, while navigating inside the generated objects.

### Limitations

While kaitai struct is awesome language-agnostic binary parsing framework, the language-agnosticity produces some limitations. Some data types are not universal between different languages, or built-in type(s) in some target languages has some not-wished side effects.
- data arrays for images and WDS scans are not parsed with correct datatype but returned as binary string. i.e. compilation to python (as one of main target languages) code does not use numpy arrays.
Specifying the right datatype for array in kaitai would cause conversion of numbers to native python number types and array would be returned as a list, which in case of images would consume a lot of memory (as every number is an object in python with its attributes and methods).
   - solution in python: The `numpy` can use the returned bytestring directly as a buffer. This allows to save memory as no array duplication is needed, but values in such array can't be modified without making a copy. 
- c# strings (in this kaitai code declared as `c_sharp_string`) has prepending 32 bit integer with lengh of the string, kaitai needs to read that before reading the string, and thus textual attributes contain one additional level. i.e. accessing comment of loaded parsed file would look like this: 

  ```python
   from somewhere_where_ksy_got_compiled_into_python_code.cameca import Cameca
   loaded_file = Cameca.from_file("at_some_path/some_stuff.qtiDat")
   print(loaded_file.header.comment.text)
  ```
  we need to use that additional `.text` argument (or a getter if working in other language than python), as `.comment` is not a string type, but special `c_sharp_string` type with two attributes (or two private attributes and coresponding getters): `length` and `text`
- Some types do not have a direct representation in all target languages. i.e. `FILETIME` or more precise `MS FILETIME`, which is parsed as 64-bit integer in the parser. It is intentended then either be cast into datetime(-like) type with built-in casting (i.e. C#) or use some custom function to convert it into standard unix timestamp.
  - Solution: unix timestamp support is more commonly built-in in languages other than C#. MS FILETIME is recalculated to UNIX TIMESTAMP as instance in ksy.
