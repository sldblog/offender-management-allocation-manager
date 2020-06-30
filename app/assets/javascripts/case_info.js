$(document).on("turbolinks:load", function(){
    if ($("#team_autocomplete").length > 0) {
        var element = document.querySelector('#team_autocomplete');
        var id = 'autocomplete-default';

        accessibleAutocomplete({
            element: element,
            id: id,
            source: team_names(),
            defaultValue: current_team(),
            onConfirm: function (val) {
                if (val !== undefined) {
                    document.getElementById("chosen_team").innerHTML = val.bold();
                }
            }
        });
    }

    if ($(".new_edit_case_information").length > 0){
        if((document.getElementById('edit_case_information_last_known_address_scotland').checked) ||
            (document.getElementById('edit_case_information_last_known_address_northern_ireland').checked)){
                hide_element();
        }
    }
});

function current_team() {
    if ($(".new_edit_case_information").length > 0){
        var team_name = document.getElementById("chosen_team").innerText;
        if (team_name !== '') {
            return team_name
        }
    }
    return ''
}

function hide_element() {
    $('.optional-case-info').hide();
}

function show_element() {
    $('.optional-case-info').show();
}

function team_names() {
    return $('.team_information').data('team')
}

function remove_team() {
    if (document.getElementById("chosen_team").innerText.length > 0) {
        document.getElementById("chosen_team").innerText = "";
        document.getElementsByName("input-autocomplete")[0].value = "";
    }
}
