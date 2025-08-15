# frozen_string_literal: true

json.errors @errors || Array(@message) || ['Unknown error has occured']
