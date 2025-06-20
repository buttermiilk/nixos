{ config, libs, pkgs, ... }:

let
  lockFile = ''
    window {
      background-color: rgba(10,10,10,1);
      color: #eeeeee
    }

    /* search entry */
    entry {
      background-color: rgba(0, 0, 0, 0.2)
    }

    button, image {
      background: none;
      border: none
    }

    button:hover {
      background-color: rgba(255, 255, 255, 0.1)
    }

    /* in case you wanted to give category buttons a different look */
    #category-button {
      margin: 0 5px 0 5px
    }

    #pinned-box {
      padding-bottom: 5px;
      border-bottom: 1px dotted gray
    }

    #files-box {
      padding: 5px;
      border: 1px dotted gray;
      border-radius: 15px
    }

    /* math operation result label */
    #math-label {
      font-weight: bold;
      font-size: 16px
    }
  '';
in {
  home.file.".config/nwg-drawer/drawer.css".text = lockFile;
}
