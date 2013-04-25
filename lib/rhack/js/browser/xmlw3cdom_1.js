// =========================================================================
//
// xmlw3cdom.js - a W3C compliant W3CDOM parser for XML for <SCRIPT>
//
// version 3.1
//
// =========================================================================
//
// Copyright (C) 2002, 2003, 2004 Jon van Noort (jon@webarcana.com.au), David Joham (djoham@yahoo.com) and Scott Severtson
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.

// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.

// You should have received a copy of the GNU Lesser General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
// visit the XML for <SCRIPT> home page at xmljs.sourceforge.net
//
// Contains text (used within comments to methods) from the
//  XML Path Language (XPath) Version 1.0 W3C Recommendation
//  Copyright ɠ16 November 1999 World Wide Web Consortium,
//  (Massachusetts Institute of Technology,
//  European Research Consortium for Informatics and Mathematics, Keio University).
//  All Rights Reserved.
//  (see: http://www.w3.org/TR/2000/WD-W3CDOM-Level-1-20000929/)

/**
 * @function addClass - add new className to classCollection
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  classCollectionStr : string - list of existing class names
 *   (separated and top and tailed with '|'s)
 * @param  newClass           : string - new class name to add
 *
 * @return : string - the new classCollection, with new className appended,
 *   (separated and top and tailed with '|'s)
 */
function addClass(classCollectionStr, newClass) {
  if (classCollectionStr) {
    if (classCollectionStr.indexOf("|"+ newClass +"|") < 0) {
      classCollectionStr += newClass + "|";
    }
  }
  else {
    classCollectionStr = "|"+ newClass + "|";
  }

  return classCollectionStr;
}

/**
 * @class  W3CDOMException - raised when an operation is impossible to perform
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  code : int - the exception code (one of the W3CDOMException constants)
 */
W3CDOMException = function(code) {
  this._class = addClass(this._class, "W3CDOMException");

  this.code = code;
};

// W3CDOMException constants
// Introduced in W3CDOM Level 1:
W3CDOMException.INDEX_SIZE_ERR                 = 1;
W3CDOMException.W3CDOMSTRING_SIZE_ERR             = 2;
W3CDOMException.HIERARCHY_REQUEST_ERR          = 3;
W3CDOMException.WRONG_DOCUMENT_ERR             = 4;
W3CDOMException.INVALID_CHARACTER_ERR          = 5;
W3CDOMException.NO_DATA_ALLOWED_ERR            = 6;
W3CDOMException.NO_MODIFICATION_ALLOWED_ERR    = 7;
W3CDOMException.NOT_FOUND_ERR                  = 8;
W3CDOMException.NOT_SUPPORTED_ERR              = 9;
W3CDOMException.INUSE_ATTRIBUTE_ERR            = 10;

// Introduced in W3CDOM Level 2:
W3CDOMException.INVALID_STATE_ERR              = 11;
W3CDOMException.SYNTAX_ERR                     = 12;
W3CDOMException.INVALID_MODIFICATION_ERR       = 13;
W3CDOMException.NAMESPACE_ERR                  = 14;
W3CDOMException.INVALID_ACCESS_ERR             = 15;


/**
 * @class  W3CDOMImplementation - provides a number of methods for performing operations
 *   that are independent of any particular instance of the document object model.
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 */
W3CDOMImplementation = function() {
  this._class = addClass(this._class, "W3CDOMImplementation");
  this._p = null;

  this.preserveWhiteSpace = false;  // by default, ignore whitespace
  this.namespaceAware = true;       // by default, handle namespaces
  this.errorChecking  = true;       // by default, test for exceptions
};


/**
 * @method W3CDOMImplementation.escapeString - escape special characters
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  str : string - The string to be escaped
 *
 * @return : string - The escaped string
 */
W3CDOMImplementation.prototype.escapeString = function W3CDOMNode__escapeString(str) {

  //the sax processor already has this function. Just wrap it
  return __escapeString(str);
};

/**
 * @method W3CDOMImplementation.unescapeString - unescape special characters
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  str : string - The string to be unescaped
 *
 * @return : string - The unescaped string
 */
W3CDOMImplementation.prototype.unescapeString = function W3CDOMNode__unescapeString(str) {

  //the sax processor already has this function. Just wrap it
  return __unescapeString(str);
};

/**
 * @method W3CDOMImplementation.hasFeature - Test if the W3CDOM implementation implements a specific feature
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  feature : string - The package name of the feature to test. the legal only values are "XML" and "CORE" (case-insensitive).
 * @param  version : string - This is the version number of the package name to test. In Level 1, this is the string "1.0".
 *
 * @return : boolean
 */
W3CDOMImplementation.prototype.hasFeature = function W3CDOMImplementation_hasFeature(feature, version) {

  var ret = false;
  if (feature.toLowerCase() == "xml") {
    ret = (!version || (version == "1.0") || (version == "2.0"));
  }
  else if (feature.toLowerCase() == "core") {
    ret = (!version || (version == "2.0"));
  }

  return ret;
};

/**
 * @method W3CDOMImplementation.loadXML - parse XML string
 *
 * @author Jon van Noort (jon@webarcana.com.au), David Joham (djoham@yahoo.com) and Scott Severtson
 *
 * @param  xmlStr : string - the XML string
 *
 * @return : W3CDOMDocument
 */
W3CDOMImplementation.prototype.loadXML = function W3CDOMImplementation_loadXML(xmlStr) {
  // create SAX Parser
  var parser;

  try {
    parser = new XMLP(xmlStr);
  }
  catch (e) {
    alert("Error Creating the SAX Parser. Did you include xmlsax.js or tinyxmlsax.js in your web page?\nThe SAX parser is needed to populate XML for <SCRIPT>'s W3C W3CDOM Parser with data.");
  }

  // create W3CDOM Document
  var doc = new W3CDOMDocument(this);

  // populate Document with Parsed Nodes
  this._parseLoop(doc, parser);

  // set parseComplete flag, (Some validation Rules are relaxed if this is false)
  doc._parseComplete = true;

  return doc;
};


/**
 * @method W3CDOMImplementation.translateErrCode - convert W3CDOMException Code
 *   to human readable error message;
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  code : int - the W3CDOMException code
 *
 * @return : string - the human readbale error message
 */
W3CDOMImplementation.prototype.translateErrCode = function W3CDOMImplementation_translateErrCode(code) {
  var msg = "";

  switch (code) {
    case W3CDOMException.INDEX_SIZE_ERR :                // 1
       msg = "INDEX_SIZE_ERR: Index out of bounds";
       break;

    case W3CDOMException.W3CDOMSTRING_SIZE_ERR :            // 2
       msg = "W3CDOMSTRING_SIZE_ERR: The resulting string is too long to fit in a W3CDOMString";
       break;

    case W3CDOMException.HIERARCHY_REQUEST_ERR :         // 3
       msg = "HIERARCHY_REQUEST_ERR: The Node can not be inserted at this location";
       break;

    case W3CDOMException.WRONG_DOCUMENT_ERR :            // 4
       msg = "WRONG_DOCUMENT_ERR: The source and the destination Documents are not the same";
       break;

    case W3CDOMException.INVALID_CHARACTER_ERR :         // 5
       msg = "INVALID_CHARACTER_ERR: The string contains an invalid character";
       break;

    case W3CDOMException.NO_DATA_ALLOWED_ERR :           // 6
       msg = "NO_DATA_ALLOWED_ERR: This Node / NodeList does not support data";
       break;

    case W3CDOMException.NO_MODIFICATION_ALLOWED_ERR :   // 7
       msg = "NO_MODIFICATION_ALLOWED_ERR: This object cannot be modified";
       break;

    case W3CDOMException.NOT_FOUND_ERR :                 // 8
       msg = "NOT_FOUND_ERR: The item cannot be found";
       break;

    case W3CDOMException.NOT_SUPPORTED_ERR :             // 9
       msg = "NOT_SUPPORTED_ERR: This implementation does not support function";
       break;

    case W3CDOMException.INUSE_ATTRIBUTE_ERR :           // 10
       msg = "INUSE_ATTRIBUTE_ERR: The Attribute has already been assigned to another Element";
       break;

// Introduced in W3CDOM Level 2:
    case W3CDOMException.INVALID_STATE_ERR :             // 11
       msg = "INVALID_STATE_ERR: The object is no longer usable";
       break;

    case W3CDOMException.SYNTAX_ERR :                    // 12
       msg = "SYNTAX_ERR: Syntax error";
       break;

    case W3CDOMException.INVALID_MODIFICATION_ERR :      // 13
       msg = "INVALID_MODIFICATION_ERR: Cannot change the type of the object";
       break;

    case W3CDOMException.NAMESPACE_ERR :                 // 14
       msg = "NAMESPACE_ERR: The namespace declaration is incorrect";
       break;

    case W3CDOMException.INVALID_ACCESS_ERR :            // 15
       msg = "INVALID_ACCESS_ERR: The object does not support this function";
       break;

    default :
       msg = "UNKNOWN: Unknown Exception Code ("+ code +")";
  }

  return msg;
}

/**
 * @method W3CDOMImplementation._parseLoop - process SAX events
 *
 * @author Jon van Noort (jon@webarcana.com.au), David Joham (djoham@yahoo.com) and Scott Severtson
 *
 * @param  doc : W3CDOMDocument - the Document to contain the parsed XML string
 * @param  p   : XMLP        - the SAX Parser
 *
 * @return : W3CDOMDocument
 */
W3CDOMImplementation.prototype._parseLoop = function W3CDOMImplementation__parseLoop(doc, p) {
  var iEvt, iNode, iAttr, strName;
  iNodeParent = doc;

  var el_close_count = 0;

  var entitiesList = new Array();
  var textNodesList = new Array();

  // if namespaceAware, add default namespace
  if (this.namespaceAware) {
    var iNS = doc.createNamespace(""); // add the default-default namespace
    iNS.setValue("http://www.w3.org/2000/xmlns/");
    doc._namespaces.setNamedItem(iNS);
  }

  // loop until SAX parser stops emitting events
  while(true) {
    // get next event
    iEvt = p.next();

    if (iEvt == XMLP._ELM_B) {                      // Begin-Element Event
      var pName = p.getName();                      // get the Element name
      pName = trim(pName, true, true);              // strip spaces from Element name

      if (!this.namespaceAware) {
        iNode = doc.createElement(p.getName());     // create the Element

        // add attributes to Element
        for(var i = 0; i < p.getAttributeCount(); i++) {
          strName = p.getAttributeName(i);          // get Attribute name
          iAttr = iNode.getAttributeNode(strName);  // if Attribute exists, use it

          if(!iAttr) {
            iAttr = doc.createAttribute(strName);   // otherwise create it
          }

          iAttr.setValue(p.getAttributeValue(i));   // set Attribute value
          iNode.setAttributeNode(iAttr);            // attach Attribute to Element
        }
      }
      else {  // Namespace Aware
        // create element (with empty namespaceURI,
        //  resolve after namespace 'attributes' have been parsed)
        iNode = doc.createElementNS("", p.getName());

        // duplicate ParentNode's Namespace definitions
        iNode._namespaces = iNodeParent._namespaces._cloneNodes(iNode);

        // add attributes to Element
        for(var i = 0; i < p.getAttributeCount(); i++) {
          strName = p.getAttributeName(i);          // get Attribute name

          // if attribute is a namespace declaration
          if (this._isNamespaceDeclaration(strName)) {
            // parse Namespace Declaration
            var namespaceDec = this._parseNSName(strName);

            if (strName != "xmlns") {
              iNS = doc.createNamespace(strName);   // define namespace
            }
            else {
              iNS = doc.createNamespace("");        // redefine default namespace
            }
            iNS.setValue(p.getAttributeValue(i));   // set value = namespaceURI

            iNode._namespaces.setNamedItem(iNS);    // attach namespace to namespace collection
          }
          else {  // otherwise, it is a normal attribute
            iAttr = iNode.getAttributeNode(strName);        // if Attribute exists, use it

            if(!iAttr) {
              iAttr = doc.createAttributeNS("", strName);   // otherwise create it
            }

            iAttr.setValue(p.getAttributeValue(i));         // set Attribute value
            iNode.setAttributeNodeNS(iAttr);                // attach Attribute to Element

            if (this._isIdDeclaration(strName)) {
              iNode.id = p.getAttributeValue(i);    // cache ID for getElementById()
            }
          }
        }

        // resolve namespaceURIs for this Element
        if (iNode._namespaces.getNamedItem(iNode.prefix)) {
          iNode.namespaceURI = iNode._namespaces.getNamedItem(iNode.prefix).value;
        }

        //  for this Element's attributes
        for (var i = 0; i < iNode.attributes.length; i++) {
          if (iNode.attributes.item(i).prefix != "") {  // attributes do not have a default namespace
            if (iNode._namespaces.getNamedItem(iNode.attributes.item(i).prefix)) {
              iNode.attributes.item(i).namespaceURI = iNode._namespaces.getNamedItem(iNode.attributes.item(i).prefix).value;
            }
          }
        }
      }

      // if this is the Root Element
      if (iNodeParent.nodeType == W3CDOMNode.DOCUMENT_NODE) {
        iNodeParent.documentElement = iNode;        // register this Element as the Document.documentElement
      }

      iNodeParent.appendChild(iNode);               // attach Element to parentNode
      iNodeParent = iNode;                          // descend one level of the W3CDOM Tree
    }

    else if(iEvt == XMLP._ELM_E) {                  // End-Element Event
      iNodeParent = iNodeParent.parentNode;         // ascend one level of the W3CDOM Tree
    }

    else if(iEvt == XMLP._ELM_EMP) {                // Empty Element Event
      pName = p.getName();                          // get the Element name
      pName = trim(pName, true, true);              // strip spaces from Element name

      if (!this.namespaceAware) {
        iNode = doc.createElement(pName);           // create the Element

        // add attributes to Element
        for(var i = 0; i < p.getAttributeCount(); i++) {
          strName = p.getAttributeName(i);          // get Attribute name
          iAttr = iNode.getAttributeNode(strName);  // if Attribute exists, use it

          if(!iAttr) {
            iAttr = doc.createAttribute(strName);   // otherwise create it
          }

          iAttr.setValue(p.getAttributeValue(i));   // set Attribute value
          iNode.setAttributeNode(iAttr);            // attach Attribute to Element
        }
      }
      else {  // Namespace Aware
        // create element (with empty namespaceURI,
        //  resolve after namespace 'attributes' have been parsed)
        iNode = doc.createElementNS("", p.getName());

        // duplicate ParentNode's Namespace definitions
        iNode._namespaces = iNodeParent._namespaces._cloneNodes(iNode);

        // add attributes to Element
        for(var i = 0; i < p.getAttributeCount(); i++) {
          strName = p.getAttributeName(i);          // get Attribute name

          // if attribute is a namespace declaration
          if (this._isNamespaceDeclaration(strName)) {
            // parse Namespace Declaration
            var namespaceDec = this._parseNSName(strName);

            if (strName != "xmlns") {
              iNS = doc.createNamespace(strName);   // define namespace
            }
            else {
              iNS = doc.createNamespace("");        // redefine default namespace
            }
            iNS.setValue(p.getAttributeValue(i));   // set value = namespaceURI

            iNode._namespaces.setNamedItem(iNS);    // attach namespace to namespace collection
          }
          else {  // otherwise, it is a normal attribute
            iAttr = iNode.getAttributeNode(strName);        // if Attribute exists, use it

            if(!iAttr) {
              iAttr = doc.createAttributeNS("", strName);   // otherwise create it
            }

            iAttr.setValue(p.getAttributeValue(i));         // set Attribute value
            iNode.setAttributeNodeNS(iAttr);                // attach Attribute to Element

            if (this._isIdDeclaration(strName)) {
              iNode.id = p.getAttributeValue(i);    // cache ID for getElementById()
            }
          }
        }

        // resolve namespaceURIs for this Element
        if (iNode._namespaces.getNamedItem(iNode.prefix)) {
          iNode.namespaceURI = iNode._namespaces.getNamedItem(iNode.prefix).value;
        }

        //  for this Element's attributes
        for (var i = 0; i < iNode.attributes.length; i++) {
          if (iNode.attributes.item(i).prefix != "") {  // attributes do not have a default namespace
            if (iNode._namespaces.getNamedItem(iNode.attributes.item(i).prefix)) {
              iNode.attributes.item(i).namespaceURI = iNode._namespaces.getNamedItem(iNode.attributes.item(i).prefix).value;
            }
          }
        }
      }

      // if this is the Root Element
      if (iNodeParent.nodeType == W3CDOMNode.DOCUMENT_NODE) {
        iNodeParent.documentElement = iNode;        // register this Element as the Document.documentElement
      }

      iNodeParent.appendChild(iNode);               // attach Element to parentNode
    }
    else if(iEvt == XMLP._TEXT || iEvt == XMLP._ENTITY) {                   // TextNode and entity Events
      // get Text content
      var pContent = p.getContent().substring(p.getContentBegin(), p.getContentEnd());
      
	  if (!this.preserveWhiteSpace ) {
		if (trim(pContent, true, true) == "") {
			pContent = ""; //this will cause us not to create the text node below
		}
	  }
	  
      if (pContent.length > 0) {                    // ignore empty TextNodes
        var textNode = doc.createTextNode(pContent);
        iNodeParent.appendChild(textNode); // attach TextNode to parentNode

        //the sax parser breaks up text nodes when it finds an entity. For
        //example hello&lt;there will fire a text, an entity and another text
        //this sucks for the dom parser because it looks to us in this logic
        //as three text nodes. I fix this by keeping track of the entity nodes
        //and when we're done parsing, calling normalize on their parent to
        //turn the multiple text nodes into one, which is what W3CDOM users expect
        //the code to do this is at the bottom of this function
        if (iEvt == XMLP._ENTITY) {
            entitiesList[entitiesList.length] = textNode;
        }
		else {
			//I can't properly decide how to handle preserve whitespace
			//until the siblings of the text node are built due to 
			//the entitiy handling described above. I don't know that this
			//will be all of the text node or not, so trimming is not appropriate
			//at this time. Keep a list of all the text nodes for now
			//and we'll process the preserve whitespace stuff at a later time.
			textNodesList[textNodesList.length] = textNode;
		}
      }
    }
    else if(iEvt == XMLP._PI) {                     // ProcessingInstruction Event
      // attach ProcessingInstruction to parentNode
      iNodeParent.appendChild(doc.createProcessingInstruction(p.getName(), p.getContent().substring(p.getContentBegin(), p.getContentEnd())));
    }
    else if(iEvt == XMLP._CDATA) {                  // CDATA Event
      // get CDATA data
      pContent = p.getContent().substring(p.getContentBegin(), p.getContentEnd());

      if (!this.preserveWhiteSpace) {
        pContent = trim(pContent, true, true);      // trim whitespace
        pContent.replace(/ +/g, ' ');               // collapse multiple spaces to 1 space
      }

      if (pContent.length > 0) {                    // ignore empty CDATANodes
        iNodeParent.appendChild(doc.createCDATASection(pContent)); // attach CDATA to parentNode
      }
    }
    else if(iEvt == XMLP._COMMENT) {                // Comment Event
      // get COMMENT data
      var pContent = p.getContent().substring(p.getContentBegin(), p.getContentEnd());

      if (!this.preserveWhiteSpace) {
        pContent = trim(pContent, true, true);      // trim whitespace
        pContent.replace(/ +/g, ' ');               // collapse multiple spaces to 1 space
      }

      if (pContent.length > 0) {                    // ignore empty CommentNodes
        iNodeParent.appendChild(doc.createComment(pContent));  // attach Comment to parentNode
      }
    }
    else if(iEvt == XMLP._DTD) {                    // ignore DTD events
    }
    else if(iEvt == XMLP._ERROR) {
      throw(new W3CDOMException(W3CDOMException.SYNTAX_ERR));
      // alert("Fatal Error: " + p.getContent() + "\nLine: " + p.getLineNumber() + "\nColumn: " + p.getColumnNumber() + "\n");
      // break;
    }
    else if(iEvt == XMLP._NONE) {                   // no more events
      if (iNodeParent == doc) {                     // confirm that we have recursed back up to root
        break;
      }
      else {
        throw(new W3CDOMException(W3CDOMException.SYNTAX_ERR));  // one or more Tags were not closed properly
      }
    }
  }

  //normalize any entities in the W3CDOM to a single textNode
  var intCount = entitiesList.length;
  for (intLoop = 0; intLoop < intCount; intLoop++) {
      var entity = entitiesList[intLoop];
      //its possible (if for example two entities were in the
      //same domnode, that the normalize on the first entitiy
      //will remove the parent for the second. Only do normalize
      //if I can find a parent node
      var parentNode = entity.getParentNode();
      if (parentNode) {
          parentNode.normalize();
		  
		  //now do whitespace (if necessary)
		  //it was not done for text nodes that have entities
		  if(!this.preserveWhiteSpace) {
		  		var children = parentNode.getChildNodes();
				var intCount2 = children.getLength();
				for ( intLoop2 = 0; intLoop2 < intCount2; intLoop2++) {
					var child = children.item(intLoop2);
					if (child.getNodeType() == W3CDOMNode.TEXT_NODE) {
						var childData = child.getData();
						childData = trim(childData, true, true);
						childData.replace(/ +/g, ' ');
						child.setData(childData);
					}
				}
		  }
      }
  }
  
  //do the preserve whitespace processing on the rest of the text nodes
  //It's possible (due to the processing above) that the node will have been
  //removed from the tree. Only do whitespace checking if parentNode is not null.
  //This may duplicate the whitespace processing for some nodes that had entities in them
  //but there's no way around that
  if (!this.preserveWhiteSpace) {
  	var intCount = textNodesList.length;
	for (intLoop = 0; intLoop < intCount; intLoop++) {
		var node = textNodesList[intLoop];
		if (node.getParentNode() != null) {
			var nodeData = node.getData();
			nodeData = trim(nodeData, true, true);
			nodeData.replace(/ +/g, ' ');
			node.setData(nodeData);
		}
	}
  
  }
};

/**
 * @method W3CDOMImplementation._isNamespaceDeclaration - Return true, if attributeName is a namespace declaration
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  attributeName : string - the attribute name
 *
 * @return : boolean
 */
W3CDOMImplementation.prototype._isNamespaceDeclaration = function W3CDOMImplementation__isNamespaceDeclaration(attributeName) {
  // test if attributeName is 'xmlns'
  return (attributeName.indexOf('xmlns') > -1);
}

/**
 * @method W3CDOMImplementation._isIdDeclaration - Return true, if attributeName is an id declaration
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  attributeName : string - the attribute name
 *
 * @return : boolean
 */
W3CDOMImplementation.prototype._isIdDeclaration = function W3CDOMImplementation__isIdDeclaration(attributeName) {
  // test if attributeName is 'id' (case insensitive)
  return (attributeName.toLowerCase() == 'id');
}

/**
 * @method W3CDOMImplementation._isValidName - Return true,
 *   if name contains no invalid characters
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  name : string - the candidate name
 *
 * @return : boolean
 */
W3CDOMImplementation.prototype._isValidName = function W3CDOMImplementation__isValidName(name) {
  // test if name contains only valid characters
  return name.match(re_validName);
}
re_validName = /^[a-zA-Z_:][a-zA-Z0-9\.\-_:]*$/;

/**
 * @method W3CDOMImplementation._isValidString - Return true, if string does not contain any illegal chars
 *  All of the characters 0 through 31 and character 127 are nonprinting control characters.
 *  With the exception of characters 09, 10, and 13, (Ox09, Ox0A, and Ox0D)
 *  Note: different from _isValidName in that ValidStrings may contain spaces
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  name : string - the candidate string
 *
 * @return : boolean
 */
W3CDOMImplementation.prototype._isValidString = function W3CDOMImplementation__isValidString(name) {
  // test that string does not contains invalid characters
  return (name.search(re_invalidStringChars) < 0);
}
re_invalidStringChars = /\x01|\x02|\x03|\x04|\x05|\x06|\x07|\x08|\x0B|\x0C|\x0E|\x0F|\x10|\x11|\x12|\x13|\x14|\x15|\x16|\x17|\x18|\x19|\x1A|\x1B|\x1C|\x1D|\x1E|\x1F|\x7F/

/**
 * @method W3CDOMImplementation._parseNSName - parse the namespace name.
 *  if there is no colon, the
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  qualifiedName : string - The qualified name
 *
 * @return : NSName - [
 *                     .prefix        : string - The prefix part of the qname
 *                     .namespaceName : string - The namespaceURI part of the qname
 *                    ]
 */
W3CDOMImplementation.prototype._parseNSName = function W3CDOMImplementation__parseNSName(qualifiedName) {
  var resultNSName = new Object();

  resultNSName.prefix          = qualifiedName;  // unless the qname has a namespaceName, the prefix is the entire String
  resultNSName.namespaceName   = "";

  // split on ':'
  delimPos = qualifiedName.indexOf(':');

  if (delimPos > -1) {
    // get prefix
    resultNSName.prefix        = qualifiedName.substring(0, delimPos);

    // get namespaceName
    resultNSName.namespaceName = qualifiedName.substring(delimPos +1, qualifiedName.length);
  }

  return resultNSName;
}

/**
 * @method W3CDOMImplementation._parseQName - parse the qualified name
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  qualifiedName : string - The qualified name
 *
 * @return : QName
 */
W3CDOMImplementation.prototype._parseQName = function W3CDOMImplementation__parseQName(qualifiedName) {
  var resultQName = new Object();

  resultQName.localName = qualifiedName;  // unless the qname has a prefix, the local name is the entire String
  resultQName.prefix    = "";

  // split on ':'
  delimPos = qualifiedName.indexOf(':');

  if (delimPos > -1) {
    // get prefix
    resultQName.prefix    = qualifiedName.substring(0, delimPos);

    // get localName
    resultQName.localName = qualifiedName.substring(delimPos +1, qualifiedName.length);
  }

  return resultQName;
}

/**
 * @class  W3CDOMNodeList - provides the abstraction of an ordered collection of nodes
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  ownerDocument : W3CDOMDocument - the ownerDocument
 * @param  parentNode    : W3CDOMNode - the node that the W3CDOMNodeList is attached to (or null)
 */
W3CDOMNodeList = function(ownerDocument, parentNode) {
  this._class = addClass(this._class, "W3CDOMNodeList");
  this._nodes = new Array();

  this.length = 0;
  this.parentNode = parentNode;
  this.ownerDocument = ownerDocument;

  this._readonly = false;
};

/**
 * @method W3CDOMNodeList.getLength - Java style gettor for .length
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @return : int
 */
W3CDOMNodeList.prototype.getLength = function W3CDOMNodeList_getLength() {
  return this.length;
};

/**
 * @method W3CDOMNodeList.item - Returns the indexth item in the collection.
 *   If index is greater than or equal to the number of nodes in the list, this returns null.
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  index : int - Index into the collection.
 *
 * @return : W3CDOMNode - The node at the indexth position in the NodeList, or null if that is not a valid index
 */
W3CDOMNodeList.prototype.item = function W3CDOMNodeList_item(index) {
  var ret = null;

  if ((index >= 0) && (index < this._nodes.length)) { // bounds check
    ret = this._nodes[index];                    // return selected Node
  }

  return ret;                                    // if the index is out of bounds, default value null is returned
};

/**
 * @method W3CDOMNodeList._findItemIndex - find the item index of the node with the specified internal id
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  id : int - unique internal id
 *
 * @return : int
 */
W3CDOMNodeList.prototype._findItemIndex = function W3CDOMNodeList__findItemIndex(id) {
  var ret = -1;

  // test that id is valid
  if (id > -1) {
    for (var i=0; i<this._nodes.length; i++) {
      // compare id to each node's _id
      if (this._nodes[i]._id == id) {            // found it!
        ret = i;
        break;
      }
    }
  }

  return ret;                                    // if node is not found, default value -1 is returned
};

/**
 * @method W3CDOMNodeList._insertBefore - insert the specified Node into the NodeList before the specified index
 *   Used by W3CDOMNode.insertBefore(). Note: W3CDOMNode.insertBefore() is responsible for Node Pointer surgery
 *   W3CDOMNodeList._insertBefore() simply modifies the internal data structure (Array).
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  newChild      : W3CDOMNode - the Node to be inserted
 * @param  refChildIndex : int     - the array index to insert the Node before
 */
W3CDOMNodeList.prototype._insertBefore = function W3CDOMNodeList__insertBefore(newChild, refChildIndex) {
  if ((refChildIndex >= 0) && (refChildIndex < this._nodes.length)) { // bounds check
    // get array containing children prior to refChild
    var tmpArr = new Array();
    tmpArr = this._nodes.slice(0, refChildIndex);

    if (newChild.nodeType == W3CDOMNode.DOCUMENT_FRAGMENT_NODE) {  // node is a DocumentFragment
      // append the children of DocumentFragment
      tmpArr = tmpArr.concat(newChild.childNodes._nodes);
    }
    else {
      // append the newChild
      tmpArr[tmpArr.length] = newChild;
    }

    // append the remaining original children (including refChild)
    this._nodes = tmpArr.concat(this._nodes.slice(refChildIndex));

    this.length = this._nodes.length;            // update length
  }
};

/**
 * @method W3CDOMNodeList._replaceChild - replace the specified Node in the NodeList at the specified index
 *   Used by W3CDOMNode.replaceChild(). Note: W3CDOMNode.replaceChild() is responsible for Node Pointer surgery
 *   W3CDOMNodeList._replaceChild() simply modifies the internal data structure (Array).
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  newChild      : W3CDOMNode - the Node to be inserted
 * @param  refChildIndex : int     - the array index to hold the Node
 */
W3CDOMNodeList.prototype._replaceChild = function W3CDOMNodeList__replaceChild(newChild, refChildIndex) {
  var ret = null;

  if ((refChildIndex >= 0) && (refChildIndex < this._nodes.length)) { // bounds check
    ret = this._nodes[refChildIndex];            // preserve old child for return

    if (newChild.nodeType == W3CDOMNode.DOCUMENT_FRAGMENT_NODE) {  // node is a DocumentFragment
      // get array containing children prior to refChild
      var tmpArr = new Array();
      tmpArr = this._nodes.slice(0, refChildIndex);

      // append the children of DocumentFragment
      tmpArr = tmpArr.concat(newChild.childNodes._nodes);

      // append the remaining original children (not including refChild)
      this._nodes = tmpArr.concat(this._nodes.slice(refChildIndex + 1));
    }
    else {
      // simply replace node in array (links between Nodes are made at higher level)
      this._nodes[refChildIndex] = newChild;
    }
  }

  return ret;                                   // return replaced node
};

/**
 * @method W3CDOMNodeList._removeChild - remove the specified Node in the NodeList at the specified index
 *   Used by W3CDOMNode.removeChild(). Note: W3CDOMNode.removeChild() is responsible for Node Pointer surgery
 *   W3CDOMNodeList._replaceChild() simply modifies the internal data structure (Array).
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  refChildIndex : int - the array index holding the Node to be removed
 */
W3CDOMNodeList.prototype._removeChild = function W3CDOMNodeList__removeChild(refChildIndex) {
  var ret = null;

  if (refChildIndex > -1) {                              // found it!
    ret = this._nodes[refChildIndex];                    // return removed node

    // rebuild array without removed child
    var tmpArr = new Array();
    tmpArr = this._nodes.slice(0, refChildIndex);
    this._nodes = tmpArr.concat(this._nodes.slice(refChildIndex +1));

    this.length = this._nodes.length;            // update length
  }

  return ret;                                   // return removed node
};

/**
 * @method W3CDOMNodeList._appendChild - append the specified Node to the NodeList
 *   Used by W3CDOMNode.appendChild(). Note: W3CDOMNode.appendChild() is responsible for Node Pointer surgery
 *   W3CDOMNodeList._appendChild() simply modifies the internal data structure (Array).
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  newChild      : W3CDOMNode - the Node to be inserted
 */
W3CDOMNodeList.prototype._appendChild = function W3CDOMNodeList__appendChild(newChild) {

  if (newChild.nodeType == W3CDOMNode.DOCUMENT_FRAGMENT_NODE) {  // node is a DocumentFragment
    // append the children of DocumentFragment
    this._nodes = this._nodes.concat(newChild.childNodes._nodes);
  }
  else {
    // simply add node to array (links between Nodes are made at higher level)
    this._nodes[this._nodes.length] = newChild;
  }

  this.length = this._nodes.length;              // update length
};

/**
 * @method W3CDOMNodeList._cloneNodes - Returns a NodeList containing clones of the Nodes in this NodeList
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  deep : boolean - If true, recursively clone the subtree under each of the nodes;
 *   if false, clone only the nodes themselves (and their attributes, if it is an Element).
 * @param  parentNode : W3CDOMNode - the new parent of the cloned NodeList
 *
 * @return : W3CDOMNodeList - NodeList containing clones of the Nodes in this NodeList
 */
W3CDOMNodeList.prototype._cloneNodes = function W3CDOMNodeList__cloneNodes(deep, parentNode) {
  var cloneNodeList = new W3CDOMNodeList(this.ownerDocument, parentNode);

  // create list containing clones of each child
  for (var i=0; i < this._nodes.length; i++) {
    cloneNodeList._appendChild(this._nodes[i].cloneNode(deep));
  }

  return cloneNodeList;
};

/**
 * @method W3CDOMNodeList.toString - Serialize this NodeList into an XML string
 *
 * @author Jon van Noort (jon@webarcana.com.au) and David Joham (djoham@yahoo.com)
 *
 * @return : string
 */
W3CDOMNodeList.prototype.toString = function W3CDOMNodeList_toString() {
  var ret = "";

  // create string containing the concatenation of the string values of each child
  for (var i=0; i < this.length; i++) {
    ret += this._nodes[i].toString();
  }

  return ret;
};

/**
 * @class  W3CDOMNamedNodeMap - used to represent collections of nodes that can be accessed by name
 *  typically a set of Element attributes
 *
 * @extends W3CDOMNodeList - note W3C spec says that this is not the case,
 *   but we need an item() method identicle to W3CDOMNodeList's, so why not?
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  ownerDocument : W3CDOMDocument - the ownerDocument
 * @param  parentNode    : W3CDOMNode - the node that the W3CDOMNamedNodeMap is attached to (or null)
 */
W3CDOMNamedNodeMap = function(ownerDocument, parentNode) {
  this._class = addClass(this._class, "W3CDOMNamedNodeMap");
  this.W3CDOMNodeList = W3CDOMNodeList;
  this.W3CDOMNodeList(ownerDocument, parentNode);
};
W3CDOMNamedNodeMap.prototype = new W3CDOMNodeList;

/**
 * @method W3CDOMNamedNodeMap.getNamedItem - Retrieves a node specified by name
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  name : string - Name of a node to retrieve
 *
 * @return : W3CDOMNode
 */
W3CDOMNamedNodeMap.prototype.getNamedItem = function W3CDOMNamedNodeMap_getNamedItem(name) {
  var ret = null;

  // test that Named Node exists
  var itemIndex = this._findNamedItemIndex(name);

  if (itemIndex > -1) {                          // found it!
    ret = this._nodes[itemIndex];                // return NamedNode
  }

  return ret;                                    // if node is not found, default value null is returned
};

/**
 * @method W3CDOMNamedNodeMap.setNamedItem - Adds a node using its nodeName attribute
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  arg : W3CDOMNode - A node to store in a named node map.
 *   The node will later be accessible using the value of the nodeName attribute of the node.
 *   If a node with that name is already present in the map, it is replaced by the new one.
 *
 * @throws : W3CDOMException - WRONG_DOCUMENT_ERR: Raised if arg was created from a different document than the one that created this map.
 * @throws : W3CDOMException - NO_MODIFICATION_ALLOWED_ERR: Raised if this NamedNodeMap is readonly.
 * @throws : W3CDOMException - INUSE_ATTRIBUTE_ERR: Raised if arg is an Attr that is already an attribute of another Element object.
 *  The W3CDOM user must explicitly clone Attr nodes to re-use them in other elements.
 *
 * @return : W3CDOMNode - If the new Node replaces an existing node with the same name the previously existing Node is returned,
 *   otherwise null is returned
 */
W3CDOMNamedNodeMap.prototype.setNamedItem = function W3CDOMNamedNodeMap_setNamedItem(arg) {
  // test for exceptions
  if (this.ownerDocument.implementation.errorChecking) {
    // throw Exception if arg was not created by this Document
    if (this.ownerDocument != arg.ownerDocument) {
      throw(new W3CDOMException(W3CDOMException.WRONG_DOCUMENT_ERR));
    }

    // throw Exception if W3CDOMNamedNodeMap is readonly
    if (this._readonly || (this.parentNode && this.parentNode._readonly)) {
      throw(new W3CDOMException(W3CDOMException.NO_MODIFICATION_ALLOWED_ERR));
    }

    // throw Exception if arg is already an attribute of another Element object
    if (arg.ownerElement && (arg.ownerElement != this.parentNode)) {
      throw(new W3CDOMException(W3CDOMException.INUSE_ATTRIBUTE_ERR));
    }
  }

  // get item index
  var itemIndex = this._findNamedItemIndex(arg.name);
  var ret = null;

  if (itemIndex > -1) {                          // found it!
    ret = this._nodes[itemIndex];                // use existing Attribute

    // throw Exception if W3CDOMAttr is readonly
    if (this.ownerDocument.implementation.errorChecking && ret._readonly) {
      throw(new W3CDOMException(W3CDOMException.NO_MODIFICATION_ALLOWED_ERR));
    }
    else {
      this._nodes[itemIndex] = arg;                // over-write existing NamedNode
    }
  }
  else {
    this._nodes[this.length] = arg;              // add new NamedNode
  }

  this.length = this._nodes.length;              // update length

  arg.ownerElement = this.parentNode;            // update ownerElement

  return ret;                                    // return old node or null
};

/**
 * @method W3CDOMNamedNodeMap.removeNamedItem - Removes a node specified by name.
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  name : string - The name of a node to remove
 *
 * @throws : W3CDOMException - NOT_FOUND_ERR: Raised if there is no node named name in this map.
 * @throws : W3CDOMException - NO_MODIFICATION_ALLOWED_ERR: Raised if this NamedNodeMap is readonly.
 *
 * @return : W3CDOMNode - The node removed from the map or null if no node with such a name exists.
 */
W3CDOMNamedNodeMap.prototype.removeNamedItem = function W3CDOMNamedNodeMap_removeNamedItem(name) {
  var ret = null;
  // test for exceptions
  // throw Exception if W3CDOMNamedNodeMap is readonly
  if (this.ownerDocument.implementation.errorChecking && (this._readonly || (this.parentNode && this.parentNode._readonly))) {
    throw(new W3CDOMException(W3CDOMException.NO_MODIFICATION_ALLOWED_ERR));
  }

  // get item index
  var itemIndex = this._findNamedItemIndex(name);

  // throw Exception if there is no node named name in this map
  if (this.ownerDocument.implementation.errorChecking && (itemIndex < 0)) {
    throw(new W3CDOMException(W3CDOMException.NOT_FOUND_ERR));
  }

  // get Node
  var oldNode = this._nodes[itemIndex];

  // throw Exception if Node is readonly
  if (this.ownerDocument.implementation.errorChecking && oldNode._readonly) {
    throw(new W3CDOMException(W3CDOMException.NO_MODIFICATION_ALLOWED_ERR));
  }

  // return removed node
  return this._removeChild(itemIndex);
};

/**
 * @method W3CDOMNamedNodeMap.getNamedItemNS - Retrieves a node specified by name
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  namespaceURI : string - the namespace URI of the required node
 * @param  localName    : string - the local name of the required node
 *
 * @return : W3CDOMNode
 */
W3CDOMNamedNodeMap.prototype.getNamedItemNS = function W3CDOMNamedNodeMap_getNamedItemNS(namespaceURI, localName) {
  var ret = null;

  // test that Named Node exists
  var itemIndex = this._findNamedItemNSIndex(namespaceURI, localName);

  if (itemIndex > -1) {                          // found it!
    ret = this._nodes[itemIndex];                // return NamedNode
  }

  return ret;                                    // if node is not found, default value null is returned
};

/**
 * @method W3CDOMNamedNodeMap.setNamedItemNS - Adds a node using
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  arg : string - A node to store in a named node map.
 *   The node will later be accessible using the value of the nodeName attribute of the node.
 *   If a node with that name is already present in the map, it is replaced by the new one.
 *
 * @throws : W3CDOMException - NO_MODIFICATION_ALLOWED_ERR: Raised if this NamedNodeMap is readonly.
 * @throws : W3CDOMException - WRONG_DOCUMENT_ERR: Raised if arg was created from a different document than the one that created this map.
 * @throws : W3CDOMException - INUSE_ATTRIBUTE_ERR: Raised if arg is an Attr that is already an attribute of another Element object.
 *   The W3CDOM user must explicitly clone Attr nodes to re-use them in other elements.
 *
 * @return : W3CDOMNode - If the new Node replaces an existing node with the same name the previously existing Node is returned,
 *   otherwise null is returned
 */
W3CDOMNamedNodeMap.prototype.setNamedItemNS = function W3CDOMNamedNodeMap_setNamedItemNS(arg) {
  // test for exceptions
  if (this.ownerDocument.implementation.errorChecking) {
    // throw Exception if W3CDOMNamedNodeMap is readonly
    if (this._readonly || (this.parentNode && this.parentNode._readonly)) {
      throw(new W3CDOMException(W3CDOMException.NO_MODIFICATION_ALLOWED_ERR));
    }

    // throw Exception if arg was not created by this Document
    if (this.ownerDocument != arg.ownerDocument) {
      throw(new W3CDOMException(W3CDOMException.WRONG_DOCUMENT_ERR));
    }

    // throw Exception if arg is already an attribute of another Element object
    if (arg.ownerElement && (arg.ownerElement != this.parentNode)) {
      throw(new W3CDOMException(W3CDOMException.INUSE_ATTRIBUTE_ERR));
    }
  }

  // get item index
  var itemIndex = this._findNamedItemNSIndex(arg.namespaceURI, arg.localName);
  var ret = null;

  if (itemIndex > -1) {                          // found it!
    ret = this._nodes[itemIndex];                // use existing Attribute
    // throw Exception if W3CDOMAttr is readonly
    if (this.ownerDocument.implementation.errorChecking && ret._readonly) {
      throw(new W3CDOMException(W3CDOMException.NO_MODIFICATION_ALLOWED_ERR));
    }
    else {
      this._nodes[itemIndex] = arg;                // over-write existing NamedNode
    }
  }
  else {
    this._nodes[this.length] = arg;              // add new NamedNode
  }

  this.length = this._nodes.length;              // update length

  arg.ownerElement = this.parentNode;


  return ret;                                    // return old node or null
};

/**
 * @method W3CDOMNamedNodeMap.removeNamedItemNS - Removes a node specified by name.
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  namespaceURI : string - the namespace URI of the required node
 * @param  localName    : string - the local name of the required node
 *
 * @throws : W3CDOMException - NOT_FOUND_ERR: Raised if there is no node with the specified namespaceURI and localName in this map.
 * @throws : W3CDOMException - NO_MODIFICATION_ALLOWED_ERR: Raised if this NamedNodeMap is readonly.
 *
 * @return : W3CDOMNode - The node removed from the map or null if no node with such a name exists.
 */
W3CDOMNamedNodeMap.prototype.removeNamedItemNS = function W3CDOMNamedNodeMap_removeNamedItemNS(namespaceURI, localName) {
  var ret = null;

  // test for exceptions
  // throw Exception if W3CDOMNamedNodeMap is readonly
  if (this.ownerDocument.implementation.errorChecking && (this._readonly || (this.parentNode && this.parentNode._readonly))) {
    throw(new W3CDOMException(W3CDOMException.NO_MODIFICATION_ALLOWED_ERR));
  }

  // get item index
  var itemIndex = this._findNamedItemNSIndex(namespaceURI, localName);

  // throw Exception if there is no matching node in this map
  if (this.ownerDocument.implementation.errorChecking && (itemIndex < 0)) {
    throw(new W3CDOMException(W3CDOMException.NOT_FOUND_ERR));
  }

  // get Node
  var oldNode = this._nodes[itemIndex];

  // throw Exception if Node is readonly
  if (this.ownerDocument.implementation.errorChecking && oldNode._readonly) {
    throw(new W3CDOMException(W3CDOMException.NO_MODIFICATION_ALLOWED_ERR));
  }

  return this._removeChild(itemIndex);             // return removed node
};

/**
 * @method W3CDOMNamedNodeMap._findNamedItemIndex - find the item index of the node with the specified name
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  name : string - the name of the required node
 *
 * @return : int
 */
W3CDOMNamedNodeMap.prototype._findNamedItemIndex = function W3CDOMNamedNodeMap__findNamedItemIndex(name) {
  var ret = -1;

  // loop through all nodes
  for (var i=0; i<this._nodes.length; i++) {
    // compare name to each node's nodeName
    if (this._nodes[i].name == name) {         // found it!
      ret = i;
      break;
    }
  }

  return ret;                                    // if node is not found, default value -1 is returned
};

/**
 * @method W3CDOMNamedNodeMap._findNamedItemNSIndex - find the item index of the node with the specified namespaceURI and localName
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  namespaceURI : string - the namespace URI of the required node
 * @param  localName    : string - the local name of the required node
 *
 * @return : int
 */
W3CDOMNamedNodeMap.prototype._findNamedItemNSIndex = function W3CDOMNamedNodeMap__findNamedItemNSIndex(namespaceURI, localName) {
  var ret = -1;

  // test that localName is not null
  if (localName) {
    // loop through all nodes
    for (var i=0; i<this._nodes.length; i++) {
      // compare name to each node's namespaceURI and localName
      if ((this._nodes[i].namespaceURI == namespaceURI) && (this._nodes[i].localName == localName)) {
        ret = i;                                 // found it!
        break;
      }
    }
  }

  return ret;                                    // if node is not found, default value -1 is returned
};

/**
 * @method W3CDOMNamedNodeMap._hasAttribute - Returns true if specified node exists
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  name : string - the name of the required node
 *
 * @return : boolean
 */
W3CDOMNamedNodeMap.prototype._hasAttribute = function W3CDOMNamedNodeMap__hasAttribute(name) {
  var ret = false;

  // test that Named Node exists
  var itemIndex = this._findNamedItemIndex(name);

  if (itemIndex > -1) {                          // found it!
    ret = true;                                  // return true
  }

  return ret;                                    // if node is not found, default value false is returned
}

/**
 * @method W3CDOMNamedNodeMap._hasAttributeNS - Returns true if specified node exists
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  namespaceURI : string - the namespace URI of the required node
 * @param  localName    : string - the local name of the required node
 *
 * @return : boolean
 */
W3CDOMNamedNodeMap.prototype._hasAttributeNS = function W3CDOMNamedNodeMap__hasAttributeNS(namespaceURI, localName) {
  var ret = false;

  // test that Named Node exists
  var itemIndex = this._findNamedItemNSIndex(namespaceURI, localName);

  if (itemIndex > -1) {                          // found it!
    ret = true;                                  // return true
  }

  return ret;                                    // if node is not found, default value false is returned
}

/**
 * @method W3CDOMNamedNodeMap._cloneNodes - Returns a NamedNodeMap containing clones of the Nodes in this NamedNodeMap
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  parentNode : W3CDOMNode - the new parent of the cloned NodeList
 *
 * @return : W3CDOMNamedNodeMap - NamedNodeMap containing clones of the Nodes in this W3CDOMNamedNodeMap
 */
W3CDOMNamedNodeMap.prototype._cloneNodes = function W3CDOMNamedNodeMap__cloneNodes(parentNode) {
  var cloneNamedNodeMap = new W3CDOMNamedNodeMap(this.ownerDocument, parentNode);

  // create list containing clones of all children
  for (var i=0; i < this._nodes.length; i++) {
    cloneNamedNodeMap._appendChild(this._nodes[i].cloneNode(false));
  }

  return cloneNamedNodeMap;
};

/**
 * @method W3CDOMNamedNodeMap.toString - Serialize this NodeMap into an XML string
 *
 * @author Jon van Noort (jon@webarcana.com.au) and David Joham (djoham@yahoo.com)
 *
 * @return : string
 */
W3CDOMNamedNodeMap.prototype.toString = function W3CDOMNamedNodeMap_toString() {
  var ret = "";

  // create string containing concatenation of all (but last) Attribute string values (separated by spaces)
  for (var i=0; i < this.length -1; i++) {
    ret += this._nodes[i].toString() +" ";
  }

  // add last Attribute to string (without trailing space)
  if (this.length > 0) {
    ret += this._nodes[this.length -1].toString();
  }

  return ret;
};

/**
 * @class  W3CDOMNamespaceNodeMap - used to represent collections of namespace nodes that can be accessed by name
 *  typically a set of Element attributes
 *
 * @extends W3CDOMNamedNodeMap
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  ownerDocument : W3CDOMDocument - the ownerDocument
 * @param  parentNode    : W3CDOMNode - the node that the W3CDOMNamespaceNodeMap is attached to (or null)
 */
W3CDOMNamespaceNodeMap = function(ownerDocument, parentNode) {
  this._class = addClass(this._class, "W3CDOMNamespaceNodeMap");
  this.W3CDOMNamedNodeMap = W3CDOMNamedNodeMap;
  this.W3CDOMNamedNodeMap(ownerDocument, parentNode);
};
W3CDOMNamespaceNodeMap.prototype = new W3CDOMNamedNodeMap;

/**
 * @method W3CDOMNamespaceNodeMap._findNamedItemIndex - find the item index of the node with the specified localName
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  localName : string - the localName of the required node
 *
 * @return : int
 */
W3CDOMNamespaceNodeMap.prototype._findNamedItemIndex = function W3CDOMNamespaceNodeMap__findNamedItemIndex(localName) {
  var ret = -1;

  // loop through all nodes
  for (var i=0; i<this._nodes.length; i++) {
    // compare name to each node's nodeName
    if (this._nodes[i].localName == localName) {         // found it!
      ret = i;
      break;
    }
  }

  return ret;                                    // if node is not found, default value -1 is returned
};


/**
 * @method W3CDOMNamespaceNodeMap._cloneNodes - Returns a NamespaceNodeMap containing clones of the Nodes in this NamespaceNodeMap
 *
 * @author Jon van Noort (jon@webarcana.com.au)
 *
 * @param  parentNode : W3CDOMNode - the new parent of the cloned NodeList
 *
 * @return : W3CDOMNamespaceNodeMap - NamespaceNodeMap containing clones of the Nodes in this NamespaceNodeMap
 */
W3CDOMNamespaceNodeMap.prototype._cloneNodes = function W3CDOMNamespaceNodeMap__cloneNodes(parentNode) {
  var cloneNamespaceNodeMap = new W3CDOMNamespaceNodeMap(this.ownerDocument, parentNode);

  // create list containing clones of all children
  for (var i=0; i < this._nodes.length; i++) {
    cloneNamespaceNodeMap._appendChild(this._nodes[i].cloneNode(false));
  }

  return cloneNamespaceNodeMap;
};